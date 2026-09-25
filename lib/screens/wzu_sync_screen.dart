import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/course.dart';
import '../services/wzu_sync_script.dart';
import '../services/zhengfang_parser.dart';
import '../widgets/glass_panel.dart';

class WzuSyncResult {
  const WzuSyncResult(this.courses, this.currentWeek);

  final List<Course> courses;
  final int currentWeek;
}

class WzuSyncScreen extends StatefulWidget {
  const WzuSyncScreen({
    super.key,
    required this.initialWeek,
    this.totalWeeks = 20,
  });

  final int initialWeek;
  final int totalWeeks;

  @override
  State<WzuSyncScreen> createState() => _WzuSyncScreenState();
}

class _WzuSyncScreenState extends State<WzuSyncScreen> {
  static final Uri _portal = Uri.parse('https://rz.wzu.edu.cn/');

  late final WebViewController _controller;
  late final TextEditingController _address;
  int _progress = 0;
  bool _loading = true;
  String _status = '正在打开温州大学统一身份认证…';
  String _extractMethod = 'dom-matrix';

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: _portal.toString());
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4F8F7))
      ..addJavaScriptChannel(
        'WzuSync',
        onMessageReceived: (message) => _handleMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.navigate,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _address.text = url;
              _status = '页面加载中…';
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _address.text = url;
              _status = '请手动进入个人课表，查询后点“提取”';
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() => _status = '页面加载失败，请检查校园网或稍后重试');
          },
        ),
      )
      ..loadRequest(_portal);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _extractCourses() async {
    if (_loading) return;
    const pendingStatus = '正在读取当前课表页面…';
    if (mounted) setState(() => _status = pendingStatus);
    try {
      await _controller.runJavaScript(wzuAssistantScript);
      await Future<void>.delayed(const Duration(seconds: 4));
      if (mounted && _status == pendingStatus) {
        setState(() => _status = '未收到提取结果。请保持在“表格”页面再试；若仍失败，请截图此提示');
      }
    } catch (_) {
      if (mounted) setState(() => _status = '无法读取当前页，请确认已经打开个人课表');
    }
  }

  Future<void> _goToAddress(String raw) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (mounted) setState(() => _status = '地址格式不正确');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.loadRequest(uri);
  }

  Future<void> _handleMessage(String raw) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    if (message['type'] == 'status') {
      final next = message['message']?.toString();
      if (next != null && mounted && next != _status) {
        setState(() => _status = next);
      }
      return;
    }
    if (message['type'] != 'courses' || message['items'] is! List) return;
    _extractMethod = message['method']?.toString() ?? 'dom-matrix';
    final courses = ZhengfangParser.parsePortalItems(message['items'] as List);
    if (courses.isEmpty) {
      if (mounted) setState(() => _status = '识别到课表页面，但没有找到可导入课程');
      return;
    }
    final locationCount = courses
        .where((course) => course.location.isNotEmpty)
        .length;
    if (mounted) {
      setState(
        () => _status = '已识别 ${courses.length} 门课，其中 $locationCount 门包含地点',
      );
    }
    await _previewImport(courses);
  }

  Future<void> _previewImport(List<Course> courses) async {
    var currentWeek = widget.initialWeek.clamp(1, widget.totalWeeks);
    final confirmedWeek = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: GlassPanel(
            borderRadius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '找到 ${courses.length} 门课程',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _extractMethod.startsWith('zhengfang-api')
                        ? '已读取正方结构化数据，并用页面上显示的教师和地点补齐缺失字段。导入只替换上次同步的课程。'
                        : _extractMethod.startsWith('zhengfang-general')
                        ? '已按正方通用课表结构读取节次、周次、地点和教师。请在确认导入前抽查几门课。'
                        : '已按合并单元格坐标解析。请重点核对星期、节次和周次；手动课程会保留。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(course.name),
                          subtitle: Text(
                            '周${'一二三四五六日'[course.weekday - 1]} '
                            '第${course.startSection}-${course.endSection}节'
                            ' · ${Course.formatWeeks(course.weeks)}'
                            '\n地点：${course.location.isEmpty ? '未提供' : course.location}',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(child: Text('这周是第几周？')),
                      DropdownButton<int>(
                        value: currentWeek,
                        items: [
                          for (var week = 1; week <= widget.totalWeeks; week++)
                            DropdownMenuItem(
                              value: week,
                              child: Text('第 $week 周'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => currentWeek = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, currentWeek),
                      icon: const Icon(Icons.cloud_done_rounded),
                      label: const Text('确认导入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmedWeek != null && mounted) {
      Navigator.of(context).pop(WzuSyncResult(courses, confirmedWeek));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统导入'),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
        actions: [
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _extractCourses,
            icon: const Icon(Icons.download_rounded),
            label: const Text('提取'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await WebViewCookieManager().clearCookies();
                await _controller.clearCache();
                await _controller.clearLocalStorage();
                await _controller.loadRequest(_portal);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('清除登录状态')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '返回上一页',
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(
                  tooltip: '前进',
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      await _controller.goForward();
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _address,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: _goToAddress,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '输入教务系统地址',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        tooltip: '打开地址',
                        onPressed: () => _goToAddress(_address.text),
                        icon: const Icon(Icons.arrow_circle_right_outlined),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _controller.reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '返回温大入口',
                  onPressed: () => _controller.loadRequest(_portal),
                  icon: const Icon(Icons.home_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: GlassPanel(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _status,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
