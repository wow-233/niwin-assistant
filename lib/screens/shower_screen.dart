import 'dart:async';

import 'package:flutter/material.dart';

import '../services/quzhi_service.dart';

class ShowerScreen extends StatefulWidget {
  const ShowerScreen({super.key});

  @override
  State<ShowerScreen> createState() => _ShowerScreenState();
}

class _ShowerScreenState extends State<ShowerScreen> {
  final _service = QuzhiService.instance;
  QuzhiSession? _session;
  QuzhiActiveOrder? _order;
  List<QuzhiDevice> _devices = [];
  String? _balance;
  String? _status;
  bool _loading = true;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final session = await _service.loadSession();
    final devices = await _service.loadDevices();
    final order = await _service.loadActiveOrder();
    if (!mounted) return;
    setState(() {
      _session = session;
      _devices = devices;
      _order = order;
      _loading = false;
    });
    _updateTicker();
    if (session != null) unawaited(_refreshBalance());
  }

  void _updateTicker() {
    _ticker?.cancel();
    if (_order != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _refreshBalance() async {
    final session = _session;
    if (session == null) return;
    try {
      final value = await _service.balance(session);
      if (mounted) setState(() => _balance = value);
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('洗澡'),
        actions: [
          if (session != null)
            IconButton(
              tooltip: '退出趣智账号',
              onPressed: _order == null ? _logout : null,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: session == null
          ? _QuzhiLogin(
              service: _service,
              onLogin: (value) async {
                await _service.saveSession(value);
                if (!mounted) return;
                setState(() {
                  _session = value;
                  _status = '登录成功';
                });
                unawaited(_refreshBalance());
              },
            )
          : _dashboard(session),
    );
  }

  Widget _dashboard(QuzhiSession session) {
    final order = _order;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name.isEmpty ? session.telephone : session.name,
                      ),
                      Text(
                        _balance == null ? '余额读取中…' : '余额 ¥$_balance',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refreshBalance,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
        if (order != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.water_drop_rounded),
                      SizedBox(width: 8),
                      Text(
                        '热水使用中',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('已使用 ${_elapsed(order.startedAt)} · 设备 ${order.snCode}'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _stop(session, order),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(_busy ? '正在结束并结算…' : '结束洗澡'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Text(
              _status!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              '我的热水设备',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: '手动添加设备编号',
              onPressed: _busy ? null : () => _manualDevice(session),
              icon: const Icon(Icons.edit_note_rounded),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _scan(session),
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: const Text('扫描'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_devices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('还没有设备。请在浴室附近打开蓝牙后扫描，也可以手动输入水表设备编号。'),
            ),
          ),
        for (final device in _devices)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.shower_outlined)),
              title: Text(device.name.isEmpty ? '热水设备' : device.name),
              subtitle: Text(
                '${device.location.isEmpty ? device.projectName : device.location}\n${device.snCode}',
              ),
              isThreeLine: true,
              trailing: order == null
                  ? FilledButton(
                      onPressed: _busy ? null : () => _start(session, device),
                      child: const Text('开始'),
                    )
                  : null,
              onLongPress: order == null ? () => _deleteDevice(device) : null,
            ),
          ),
        const SizedBox(height: 14),
        const Text(
          '本功能只负责登录、查找设备和控制热水，不提供注册或充值。开始前请确认设备编号、余额和水龙头状态；结束时请等待结算完成。',
        ),
      ],
    );
  }

  Future<void> _scan(QuzhiSession session) async {
    setState(() {
      _busy = true;
      _status = '正在扫描附近热水设备（约 12 秒）…';
    });
    try {
      final candidates = await _service.scanNearby();
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() => _status = '没有找到设备，请靠近水表并确认蓝牙已开启');
        return;
      }
      final selected = await showModalBottomSheet<QuzhiDevice>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('选择附近设备')),
              for (final item in candidates)
                ListTile(
                  leading: const Icon(Icons.bluetooth_rounded),
                  title: Text(item.name),
                  subtitle: Text('${item.snCode} · 信号 ${item.rssi} dBm'),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      setState(() => _status = '正在核对设备信息…');
      final resolved = await _service.resolveDevice(session, selected);
      await _service.saveDevice(resolved);
      _devices = await _service.loadDevices();
      if (mounted) {
        setState(
          () => _status =
              '已添加 ${resolved.location.isEmpty ? resolved.name : resolved.location}',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualDevice(QuzhiSession session) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入设备编号'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'SN 或蓝牙 MAC 地址'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final normalized = value.toUpperCase();
      final candidate = QuzhiDevice(
        snCode: normalized.replaceAll(':', ''),
        name: '热水设备',
        address: normalized.contains(':') ? normalized : '',
      );
      final resolved = await _service.resolveDevice(session, candidate);
      await _service.saveDevice(resolved);
      _devices = await _service.loadDevices();
      if (mounted) setState(() => _status = '设备已添加');
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(QuzhiSession session, QuzhiDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开始使用热水？'),
        content: Text(
          '设备：${device.location.isEmpty ? device.snCode : device.location}\n请确认已经打开对应水龙头。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _status = '正在启动热水，请勿重复点击…';
    });
    try {
      final order = await _service.start(session, device);
      if (!mounted) return;
      setState(() {
        _order = order;
        _status = '热水已启动';
      });
      _updateTicker();
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(QuzhiSession session, QuzhiActiveOrder order) async {
    setState(() {
      _busy = true;
      _status = '正在关闭热水并等待账单…';
    });
    try {
      final consumed = await _service.stop(session, order);
      if (!mounted) return;
      setState(() {
        _order = null;
        _status = consumed == null ? '热水已关闭' : '热水已关闭，本次消费 ¥$consumed';
      });
      _updateTicker();
      unawaited(_refreshBalance());
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDevice(QuzhiDevice device) async {
    await _service.deleteDevice(device.snCode);
    _devices = await _service.loadDevices();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await _service.logout();
    if (mounted) {
      setState(() {
        _session = null;
        _devices = [];
        _balance = null;
        _status = null;
      });
    }
  }

  String _elapsed(DateTime startedAt) {
    final duration = DateTime.now().difference(startedAt);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _QuzhiLogin extends StatefulWidget {
  const _QuzhiLogin({required this.service, required this.onLogin});
  final QuzhiService service;
  final ValueChanged<QuzhiSession> onLogin;

  @override
  State<_QuzhiLogin> createState() => _QuzhiLoginState();
}

class _QuzhiLoginState extends State<_QuzhiLogin> {
  final _phone = TextEditingController();
  final _secret = TextEditingController();
  bool _sms = true;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _phone.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _validPhone => RegExp(r'^\d{11}$').hasMatch(_phone.text);

  Future<void> _sendCode() async {
    if (!_validPhone) {
      setState(() => _message = '请输入 11 位手机号');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.sendCode(_phone.text);
      if (mounted) setState(() => _message = '验证码已发送');
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!_validPhone || _secret.text.isEmpty) {
      setState(() => _message = '请填写完整登录信息');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = _sms
          ? await widget.service.loginSms(_phone.text, _secret.text)
          : await widget.service.loginPassword(_phone.text, _secret.text);
      widget.onLogin(session);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        '登录趣智校园',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text('应用内完成登录、设备扫描和热水开关。泥win助手不提供注册或充值。'),
      const SizedBox(height: 20),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('验证码')),
          ButtonSegment(value: false, label: Text('密码')),
        ],
        selected: {_sms},
        onSelectionChanged: (value) => setState(() {
          _sms = value.first;
          _secret.clear();
        }),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        maxLength: 11,
        decoration: const InputDecoration(
          labelText: '手机号',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _secret,
              obscureText: !_sms,
              keyboardType: _sms
                  ? TextInputType.number
                  : TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: _sms ? '验证码' : '密码',
                prefixIcon: Icon(
                  _sms ? Icons.sms_outlined : Icons.lock_outline_rounded,
                ),
              ),
            ),
          ),
          if (_sms) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _busy ? null : _sendCode,
              child: const Text('获取验证码'),
            ),
          ],
        ],
      ),
      if (_message != null) ...[
        const SizedBox(height: 10),
        Text(
          _message!,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _busy ? null : _login,
        icon: const Icon(Icons.login_rounded),
        label: Text(_busy ? '处理中…' : '登录'),
      ),
      const SizedBox(height: 18),
      const Text('登录成功后只保存服务器会话，不保存你输入的密码或验证码；会话和设备信息使用系统安全存储。'),
    ],
  );
}
