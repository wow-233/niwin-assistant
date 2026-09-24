import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AcademicStatusScreen extends StatefulWidget {
  const AcademicStatusScreen({super.key});

  @override
  State<AcademicStatusScreen> createState() => _AcademicStatusScreenState();
}

class _AcademicStatusScreenState extends State<AcademicStatusScreen> {
  static final _target = Uri.parse(
    'http://jwxt.wzu.edu.cn/jwglxt/xsxy/xsxyqk_cxXsxyqkIndex.html?echarts=1&gnmkdm=N105515&layout=default',
  );
  late final WebViewController _controller;
  int _progress = 0;
  bool _extracting = false;
  List<_AcademicGroup>? _groups;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AcademicSync',
        onMessageReceived: (message) => _handleResult(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        ),
      )
      ..loadRequest(_target);
  }

  Future<void> _extract() async {
    if (_extracting) return;
    setState(() => _extracting = true);
    try {
      await _controller.runJavaScript(_extractScript);
      Future<void>.delayed(const Duration(seconds: 25), () {
        if (!mounted || !_extracting) return;
        setState(() => _extracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('读取超时，请确认已登录且当前网络可访问教务系统')),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$error')));
      }
      if (mounted) setState(() => _extracting = false);
    }
  }

  void _handleResult(String raw) {
    if (!mounted) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['error'] != null) {
        throw FormatException(decoded['error'].toString());
      }
      final list = decoded is Map ? decoded['groups'] : null;
      final groups = (list is List ? list : const [])
          .whereType<Map>()
          .map(
            (item) => _AcademicGroup.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.rows.isNotEmpty)
          .toList();
      setState(() {
        _extracting = false;
        if (groups.isNotEmpty) _groups = groups;
      });
      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有读取到培养方案数据，请确认已登录并打开学生学业情况页面')),
        );
      }
    } catch (error) {
      setState(() => _extracting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('学业数据解析失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学生学业情况'),
        actions: [
          IconButton(
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          FilledButton.tonalIcon(
            onPressed: _progress < 100 || _extracting ? null : _extract,
            icon: _extracting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_tree_outlined),
            label: const Text('读取'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: _groups == null
          ? Column(
              children: [
                MaterialBanner(
                  content: const Text(
                    '请在学校页面完成登录，进入“学生学业情况”后点右上角读取。只解析当前页面，不保存账号密码。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _controller.loadRequest(_target),
                      child: const Text('打开目标页'),
                    ),
                  ],
                ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            )
          : _AcademicTree(
              groups: _groups!,
              onBack: () => setState(() => _groups = null),
            ),
    );
  }
}

class _AcademicTree extends StatelessWidget {
  const _AcademicTree({required this.groups, required this.onBack});
  final List<_AcademicGroup> groups;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.language_rounded),
          label: const Text('返回学校页面'),
        ),
      ),
      for (final group in groups)
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: groups.length <= 4,
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(
              group.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${group.rows.length} 项'),
            children: [
              for (final row in group.rows)
                ListTile(
                  dense: true,
                  title: Text(
                    row.first,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: row.length > 2
                      ? Text(row.sublist(1, row.length - 1).join(' · '))
                      : null,
                  trailing: row.length > 1
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(row.last, textAlign: TextAlign.end),
                        )
                      : null,
                ),
            ],
          ),
        ),
    ],
  );
}

class _AcademicGroup {
  const _AcademicGroup(this.title, this.rows);
  final String title;
  final List<List<String>> rows;

  factory _AcademicGroup.fromJson(Map<String, dynamic> json) => _AcademicGroup(
    json['title']?.toString() ?? '学业信息',
    (json['rows'] as List<dynamic>? ?? const [])
        .whereType<List>()
        .map(
          (row) => row
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(),
        )
        .where((row) => row.isNotEmpty)
        .toList(),
  );
}

const _extractScript = r'''
(async () => {
  const clean = value => String(value || '').replace(/\s+/g, ' ').trim();
  const groups = [];
  try {
    const summary = clean(document.querySelector('#alertBox')?.textContent);
    if (summary) groups.push({title: '学业概览', rows: [[summary]]});
    const nodes = [...document.querySelectorAll('span[id^="showKc"]')];
    if (!nodes.length) throw new Error('当前页面没有找到培养方案节点');
    const marker = location.pathname.indexOf('/xsxy/');
    const root = marker >= 0 ? location.pathname.substring(0, marker) : '/jwglxt';
    const endpoint = root.replace(/\/$/, '') +
      '/xsxy/xsxyqk_cxJxzxjhxfyqKcxx.html?gnmkdm=N105515';
    for (const node of nodes) {
      const id = String(node.id || '').replace(/^showKc/, '');
      if (!id) continue;
      let container = node.parentElement;
      for (let depth = 0; container && depth < 7; depth++) {
        if (/要求学分|获得学分|未获得学分/.test(clean(container.textContent))) break;
        container = container.parentElement;
      }
      container = container || node.closest('li, .panel, .row, tr, div') || node.parentElement;
      const text = clean(container?.textContent);
      const title = clean(text.split(/要求学分|获得学分|未获得学分/)[0]) || `培养方案 ${id}`;
      const credits = text.match(/要求学分\s*[:：]?\s*([\d.]+).*?获得学分\s*[:：]?\s*([\d.]+).*?未获得学分\s*[:：]?\s*([\d.]+)/);
      const response = await fetch(endpoint, {
        method: 'POST',
        credentials: 'include',
        headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
        body: new URLSearchParams({xfyqjd_id: id}).toString()
      });
      if (!response.ok) throw new Error(`${title}读取失败：HTTP ${response.status}`);
      const payload = await response.json();
      const list = Array.isArray(payload) ? payload : (payload.items || payload.rows || []);
      const rows = [];
      if (credits) rows.push(['学分进度', `要求 ${credits[1]}`, `已获 ${credits[2]}`, `未获 ${credits[3]}`]);
      for (const item of list) {
        const status = Number(item.XDZT) === 1 ? '已修' : (Number(item.XDZT) === 0 ? '未修' : '修读中');
        rows.push([
          clean(item.KCMC || item.kcmc || item.KCH || '未命名课程'),
          clean(item.KCXZMC || item.kcxzmc || ''),
          item.XF == null ? '' : `学分 ${item.XF}`,
          item.MAXCJ == null ? '' : `成绩 ${item.MAXCJ}`,
          item.JD == null ? '' : `绩点 ${item.JD}`,
          status
        ].filter(Boolean));
      }
      if (rows.length) groups.push({title, rows});
    }
    AcademicSync.postMessage(JSON.stringify({groups}));
  } catch (error) {
    AcademicSync.postMessage(JSON.stringify({error: String(error?.message || error)}));
  }
})()
''';
