import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AcademicStatusScreen extends StatefulWidget {
  const AcademicStatusScreen({super.key});

  @override
  State<AcademicStatusScreen> createState() => _AcademicStatusScreenState();
}

class _AcademicStatusScreenState extends State<AcademicStatusScreen> {
  static const _cacheKey = 'academicStatus.cache.v2';
  static final _target = Uri.parse(
    'http://jwxt.wzu.edu.cn/jwglxt/xsxy/xsxyqk_cxXsxyqkIndex.html?echarts=1&gnmkdm=N105515&layout=default',
  );

  late final WebViewController _controller;
  int _progress = 100;
  int _extractionToken = 0;
  bool _loadingCache = true;
  bool _webLoaded = false;
  bool _extracting = false;
  DateTime? _savedAt;
  List<_AcademicGroup>? _groups;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AcademicSync',
        onMessageReceived: (message) =>
            unawaited(_handleResult(message.message)),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted && _webLoaded) setState(() => _progress = value);
          },
        ),
      );
    unawaited(_restoreCache());
  }

  Future<void> _restoreCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final groups = _parseGroups(map['groups']);
          if (groups.isNotEmpty) {
            _groups = groups;
            _savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
          }
        }
      }
    } catch (_) {
      _groups = null;
    }
    if (!mounted) return;
    setState(() => _loadingCache = false);
    if (_groups == null) await _openPortal();
  }

  Future<void> _openPortal() async {
    if (!mounted) return;
    setState(() {
      _groups = null;
      _webLoaded = true;
      _progress = 0;
      _extracting = false;
    });
    try {
      await _controller.loadRequest(_target);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('教务页面打开失败：$error')));
    }
  }

  Future<void> _extract() async {
    if (_extracting) return;
    final token = ++_extractionToken;
    setState(() => _extracting = true);
    try {
      await _controller.runJavaScript(_extractScript);
      Future<void>.delayed(const Duration(seconds: 30), () {
        if (!mounted || !_extracting || token != _extractionToken) return;
        setState(() => _extracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('读取超时，请确认已登录并已打开学生学业情况页面')),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _extracting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('读取失败：$error')));
    }
  }

  Future<void> _handleResult(String raw) async {
    if (!mounted) return;
    _extractionToken++;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['error'] != null) {
        throw FormatException(decoded['error'].toString());
      }
      final groups = _parseGroups(decoded is Map ? decoded['groups'] : null);
      if (groups.isEmpty) {
        setState(() => _extracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有读取到培养方案数据，请确认已经登录正确账号')),
        );
        return;
      }
      final savedAt = DateTime.now();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _cacheKey,
        jsonEncode({
          'savedAt': savedAt.toIso8601String(),
          'groups': groups.map((item) => item.toJson()).toList(),
        }),
      );
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _webLoaded = false;
        _groups = groups;
        _savedAt = savedAt;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _extracting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('学业数据解析失败：$error')));
    }
  }

  List<_AcademicGroup> _parseGroups(dynamic value) {
    return (value is List ? value : const [])
        .whereType<Map>()
        .map((item) => _AcademicGroup.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.courses.isNotEmpty || item.summary.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCache) {
      return const Scaffold(body: SafeArea(child: _AcademicSkeleton()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('学生学业情况'),
        actions: [
          if (_groups != null)
            IconButton(
              tooltip: '重新登录并读取',
              onPressed: _openPortal,
              icon: const Icon(Icons.sync_rounded),
            )
          else ...[
            IconButton(
              tooltip: '刷新网页',
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
        ],
        bottom: _groups == null && _progress < 100
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
                    '请登录教务系统并打开“学生学业情况”，然后点右上角读取。读取成功后会保存在本机，下次无需重新登录。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _controller.loadRequest(_target),
                      child: const Text('目标页面'),
                    ),
                  ],
                ),
                Expanded(child: WebViewWidget(controller: _controller)),
              ],
            )
          : _AcademicTree(
              groups: _groups!,
              savedAt: _savedAt,
              onRefresh: _openPortal,
            ),
    );
  }
}

class _AcademicTree extends StatelessWidget {
  const _AcademicTree({
    required this.groups,
    required this.savedAt,
    required this.onRefresh,
  });

  final List<_AcademicGroup> groups;
  final DateTime? savedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final courseCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.courses.length,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.school_outlined, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${groups.length} 个培养方案分类 · $courseCount 门课程',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        savedAt == null
                            ? '本机缓存'
                            : '更新于 ${_formatTime(savedAt!)}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '更新数据',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.sync_rounded),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final group in groups) _AcademicGroupCard(group: group),
      ],
    );
  }

  static String _formatTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _AcademicGroupCard extends StatefulWidget {
  const _AcademicGroupCard({required this.group});
  final _AcademicGroup group;

  @override
  State<_AcademicGroupCard> createState() => _AcademicGroupCardState();
}

class _AcademicGroupCardState extends State<_AcademicGroupCard> {
  late bool _expanded = widget.group.courses.length <= 8;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(
          group.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              if (group.requiredCredits.isNotEmpty)
                _MiniLabel('要求 ${group.requiredCredits}'),
              if (group.earnedCredits.isNotEmpty)
                _MiniLabel('已获 ${group.earnedCredits}'),
              if (group.missingCredits.isNotEmpty)
                _MiniLabel('未获 ${group.missingCredits}'),
              if (group.courses.isNotEmpty)
                _MiniLabel('${group.courses.length} 门'),
            ],
          ),
        ),
        children: [
          if (_expanded && group.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(group.summary),
              ),
            ),
          if (_expanded)
            for (final course in group.courses)
              _AcademicCourseTile(course: course),
        ],
      ),
    );
  }
}

class _AcademicCourseTile extends StatefulWidget {
  const _AcademicCourseTile({required this.course});
  final _AcademicCourse course;

  @override
  State<_AcademicCourseTile> createState() => _AcademicCourseTileState();
}

class _AcademicCourseTileState extends State<_AcademicCourseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final scheme = Theme.of(context).colorScheme;
    final completed = course.status.contains('已修');
    return ExpansionTile(
      onExpansionChanged: (value) => setState(() => _expanded = value),
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      leading: Icon(
        completed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        color: completed ? scheme.primary : scheme.outline,
      ),
      title: Text(
        course.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          course.code,
          course.nature,
          course.credits.isEmpty ? '' : '${course.credits} 学分',
        ].where((value) => value.isNotEmpty).join(' · '),
      ),
      trailing: _StatusLabel(text: course.status),
      children: [
        if (_expanded)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final detail in course.details)
                  _DetailLabel(label: detail.label, value: detail.value),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 78),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 112),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _AcademicSkeleton extends StatelessWidget {
  const _AcademicSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final height in [100.0, 150.0, 150.0]) ...[
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class _AcademicGroup {
  const _AcademicGroup({
    required this.title,
    required this.summary,
    required this.requiredCredits,
    required this.earnedCredits,
    required this.missingCredits,
    required this.courses,
  });

  final String title;
  final String summary;
  final String requiredCredits;
  final String earnedCredits;
  final String missingCredits;
  final List<_AcademicCourse> courses;

  Map<String, Object> toJson() => {
    'title': title,
    'summary': summary,
    'requiredCredits': requiredCredits,
    'earnedCredits': earnedCredits,
    'missingCredits': missingCredits,
    'courses': courses.map((item) => item.toJson()).toList(),
  };

  factory _AcademicGroup.fromJson(Map<String, dynamic> json) => _AcademicGroup(
    title: json['title']?.toString() ?? '学业信息',
    summary: json['summary']?.toString() ?? '',
    requiredCredits: json['requiredCredits']?.toString() ?? '',
    earnedCredits: json['earnedCredits']?.toString() ?? '',
    missingCredits: json['missingCredits']?.toString() ?? '',
    courses: (json['courses'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => _AcademicCourse.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}

class _AcademicCourse {
  const _AcademicCourse({
    required this.name,
    required this.code,
    required this.nature,
    required this.credits,
    required this.status,
    required this.details,
  });

  final String name;
  final String code;
  final String nature;
  final String credits;
  final String status;
  final List<_AcademicDetail> details;

  Map<String, Object> toJson() => {
    'name': name,
    'code': code,
    'nature': nature,
    'credits': credits,
    'status': status,
    'details': details.map((item) => item.toJson()).toList(),
  };

  factory _AcademicCourse.fromJson(Map<String, dynamic> json) =>
      _AcademicCourse(
        name: json['name']?.toString() ?? '未命名课程',
        code: json['code']?.toString() ?? '',
        nature: json['nature']?.toString() ?? '',
        credits: json['credits']?.toString() ?? '',
        status: json['status']?.toString() ?? '状态未知',
        details: (json['details'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  _AcademicDetail.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
}

class _AcademicDetail {
  const _AcademicDetail(this.label, this.value);
  final String label;
  final String value;

  Map<String, String> toJson() => {'label': label, 'value': value};

  factory _AcademicDetail.fromJson(Map<String, dynamic> json) =>
      _AcademicDetail(
        json['label']?.toString() ?? '信息',
        json['value']?.toString() ?? '',
      );
}

const _extractScript = r'''
(async () => {
  const clean = value => String(value ?? '').replace(/\s+/g, ' ').trim();
  const value = (item, ...keys) => {
    for (const key of keys) {
      const found = item[key] ?? item[key.toLowerCase()];
      if (found !== null && found !== undefined && clean(found)) return clean(found);
    }
    return '';
  };
  const groups = [];
  try {
    const summary = clean(document.querySelector('#alertBox')?.textContent);
    if (summary) {
      groups.push({
        title: '学业概览', summary, requiredCredits: '', earnedCredits: '',
        missingCredits: '', courses: []
      });
    }
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
      const courses = [];
      for (const item of list) {
        const state = Number(item.XDZT ?? item.xdzt);
        const status = state === 1 ? '已修' : (state === 0 ? '未修' : '修读中');
        const name = value(item, 'KCMC', 'kcmc', 'KCH');
        const code = value(item, 'KCH', 'kch', 'KCH_ID');
        const nature = value(item, 'KCXZMC', 'kcxzmc');
        const courseCredits = value(item, 'XF', 'xf');
        const suggestedYear = value(item, 'JYXDXNM', 'jyxdxnm');
        const suggestedTerm = value(item, 'JYXDXQMC', 'jyxdxqmc');
        const fields = [
          ['课程代码', code],
          ['课程性质', nature],
          ['课程类别', value(item, 'KCLBMC', 'kclbmc')],
          ['课程归属', value(item, 'KCGSMC', 'kcgsmc')],
          ['课程模块', value(item, 'KCMKMC', 'kcmkmc')],
          ['学分', courseCredits],
          ['最高成绩', value(item, 'MAXCJ', 'maxcj')],
          ['绩点', value(item, 'JD', 'jd')],
          ['建议学年', suggestedYear],
          ['建议学期', suggestedTerm],
          ['学年学期', value(item, 'XNXQMC', 'xnxqmc', 'XNMC', 'xnmc')],
          ['开课学院', value(item, 'KKXYMC', 'kkxymc')],
          ['考核方式', value(item, 'KHKSMC', 'khksmc')],
          ['成绩备注', value(item, 'CJBZ', 'cjbz')],
          ['修读状态', status]
        ].filter(entry => entry[1]);
        courses.push({
          name: name || '未命名课程', code, nature, credits: courseCredits,
          status, details: fields.map(entry => ({label: entry[0], value: entry[1]}))
        });
      }
      groups.push({
        title,
        summary: '',
        requiredCredits: credits?.[1] || '',
        earnedCredits: credits?.[2] || '',
        missingCredits: credits?.[3] || '',
        courses
      });
    }
    AcademicSync.postMessage(JSON.stringify({groups}));
  } catch (error) {
    AcademicSync.postMessage(JSON.stringify({error: String(error?.message || error)}));
  }
})()
''';
