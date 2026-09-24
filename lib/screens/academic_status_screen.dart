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
      final raw = await _controller.runJavaScriptReturningResult(
        _extractScript,
      );
      dynamic decoded = raw;
      if (decoded is String) {
        decoded = jsonDecode(decoded);
        if (decoded is String) decoded = jsonDecode(decoded);
      }
      final list = decoded is List ? decoded : const [];
      final groups = list
          .whereType<Map>()
          .map(
            (item) => _AcademicGroup.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.rows.isNotEmpty)
          .toList();
      if (!mounted) return;
      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有读取到学业数据，请先登录并等待页面完全加载')),
        );
      } else {
        setState(() => _groups = groups);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
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
(() => {
  const clean = value => String(value || '').replace(/\s+/g, ' ').trim();
  const groups = [];
  const seen = new Set();
  const headingFor = node => {
    const own = node.querySelector('caption, .panel-title, .card-title, legend');
    if (own && clean(own.textContent)) return clean(own.textContent);
    let prev = node.previousElementSibling;
    for (let i = 0; prev && i < 5; i++, prev = prev.previousElementSibling) {
      if (/^H[1-6]$/.test(prev.tagName) || prev.matches('.title,.panel-heading,.tab-title')) {
        const value = clean(prev.textContent); if (value) return value;
      }
    }
    return '学业信息';
  };
  const documents = [document];
  for (const frame of document.querySelectorAll('iframe')) {
    try { if (frame.contentDocument) documents.push(frame.contentDocument); } catch (_) {}
  }
  for (const doc of documents) {
    for (const table of doc.querySelectorAll('table')) {
      const rows = [...table.querySelectorAll('tr')].map(tr =>
        [...tr.querySelectorAll(':scope > th, :scope > td')].map(cell => clean(cell.textContent)).filter(Boolean)
      ).filter(row => row.length);
      if (!rows.length) continue;
      const title = headingFor(table);
      const key = title + JSON.stringify(rows);
      if (!seen.has(key)) { seen.add(key); groups.push({title, rows}); }
    }
    const pairs = [];
    for (const node of doc.querySelectorAll('dl, .form-group, .info-item, [class*=credit], [class*=score]')) {
      const labels = [...node.querySelectorAll('dt,dd,label,.control-label,.value')].map(x => clean(x.textContent)).filter(Boolean);
      if (labels.length >= 2 && labels.length <= 8) pairs.push(labels);
    }
    if (pairs.length) groups.push({title: '页面补充信息', rows: pairs});
  }
  return JSON.stringify(groups);
})()
''';
