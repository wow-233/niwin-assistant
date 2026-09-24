import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../services/webdav_service.dart';

class WebDavScreen extends StatefulWidget {
  const WebDavScreen({super.key, required this.store});
  final ScheduleStore store;

  @override
  State<WebDavScreen> createState() => _WebDavScreenState();
}

class _WebDavScreenState extends State<WebDavScreen> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _hidePassword = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await WebDavService.instance.loadConfig();
    if (!mounted) return;
    _url.text = config.url;
    _username.text = config.username;
    _password.text = config.password;
    setState(() => _loading = false);
  }

  WebDavConfig get _config => WebDavConfig(
    url: _url.text.trim(),
    username: _username.text.trim(),
    password: _password.text,
  );

  Future<bool> _save() async {
    try {
      await WebDavService.instance.saveConfig(_config);
      if (mounted) setState(() => _status = '配置已安全保存');
      return true;
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
      return false;
    }
  }

  Future<void> _upload() async {
    if (!await _save()) return;
    setState(() {
      _busy = true;
      _status = '正在上传课表…';
    });
    try {
      await WebDavService.instance.upload(
        _config,
        widget.store.exportTimetableJson(),
      );
      if (mounted) {
        setState(() => _status = '课表上传成功 · ${_time(DateTime.now())}');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (!await _save()) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 WebDAV 恢复课表？'),
        content: const Text('只会替换学期、课程与作息时间；作业、快捷入口和其他设置不会改变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _status = '正在下载并校验课表…';
    });
    try {
      final raw = await WebDavService.instance.download(_config);
      await widget.store.importTimetableJson(raw);
      if (mounted) {
        setState(() => _status = '课表恢复成功 · ${_time(DateTime.now())}');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WebDAV 课表同步')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'WebDAV 文件地址',
                          hintText:
                              'https://dav.example.com/niwin/timetable.json',
                          prefixIcon: Icon(Icons.cloud_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _username,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: '密码或应用密码',
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _save,
                          child: const Text('保存配置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _status!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _upload,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('上传课表'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('恢复课表'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    '仅同步学期、课程和作息时间，不上传作业、倒计时、浏览记录、趣智会话或其他偏好。凭据使用系统安全存储。请先在 WebDAV 中创建目标文件夹，并填写完整 JSON 文件地址。',
                  ),
                ),
              ),
            ],
          ),
  );

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
