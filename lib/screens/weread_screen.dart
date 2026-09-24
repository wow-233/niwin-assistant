import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../services/weread_service.dart';

class ExperimentalScreen extends StatefulWidget {
  const ExperimentalScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  State<ExperimentalScreen> createState() => _ExperimentalScreenState();
}

class _ExperimentalScreenState extends State<ExperimentalScreen> {
  String? _maskedKey;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    _maskedKey = await WereadService.instance.maskedApiKey();
    if (mounted) setState(() {});
  }

  Future<void> _editKey() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('微信读书 API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: 'wrk-xxxxxxxx',
            helperText: '使用系统加密存储；不会写入备份文件',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await WereadService.instance.saveApiKey(value);
      await widget.store.setWereadEnabled(true);
      await _loadKey();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('实验性功能')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.history_rounded),
                    title: const Text('操作时间线'),
                    subtitle: const Text('开启后记录课程添加、修改、导入和学期切换'),
                    value: widget.store.timelineEnabled,
                    onChanged: widget.store.setTimelineEnabled,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.account_tree_outlined),
                    title: const Text('学生学业情况'),
                    subtitle: const Text('登录教务系统后读取并整理为树状卡片'),
                    value: widget.store.academicEnabled,
                    onChanged: widget.store.setAcademicEnabled,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.shower_outlined),
                    title: const Text('趣智轻享洗澡快捷入口'),
                    subtitle: const Text('在“我的”一键打开 quzhi-lite；未安装时打开项目页'),
                    value: widget.store.showerEnabled,
                    onChanged: widget.store.setShowerEnabled,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_stories_outlined),
                    title: const Text('微信读书统计'),
                    subtitle: const Text('在“我的”显示本月阅读天数与时长'),
                    value: widget.store.wereadEnabled,
                    onChanged: (value) async {
                      if (value && _maskedKey == null) {
                        await _editKey();
                      } else {
                        await widget.store.setWereadEnabled(value);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('API Key'),
                    subtitle: Text(_maskedKey ?? '未设置'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _editKey,
                  ),
                  if (_maskedKey != null) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: const Text('移除 API Key'),
                      onTap: () async {
                        await WereadService.instance.clear();
                        await widget.store.setWereadEnabled(false);
                        await _loadKey();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('实验功能默认关闭；开启后才会在“我的”显示入口。微信读书统计默认缓存 6 小时。'),
            ),
          ],
        ),
      ),
    );
  }
}

class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen> {
  late Future<ReadingStats> _future = WereadService.instance.getMonthlyStats();

  void _refresh() {
    setState(() {
      _future = WereadService.instance.getMonthlyStats(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微信读书统计'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<ReadingStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ReadingSkeleton();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: _refresh, child: const Text('重试')),
                  ],
                ),
              ),
            );
          }
          final stats = snapshot.requireData;
          final values = stats.dailySeconds.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: '本月阅读',
                      value: stats.durationLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: '阅读天数',
                      value: '${stats.readDays} 天',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '每日时长',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 190,
                        child: CustomPaint(
                          painter: _ReadingBars(
                            values: values.map((entry) => entry.value).toList(),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '缓存于 ${stats.cachedAt.month}/${stats.cachedAt.day} '
                  '${stats.cachedAt.hour.toString().padLeft(2, '0')}:${stats.cachedAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _ReadingBars extends CustomPainter {
  const _ReadingBars({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = values.length > 31
        ? values.sublist(values.length - 31)
        : values;
    if (shown.isEmpty) return;
    final maxValue = shown.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 31);
    final gap = 3.0;
    final width = (size.width - gap * (shown.length - 1)) / shown.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < shown.length; i++) {
      final height = size.height * shown[i] / maxValue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (width + gap), size.height - height, width, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReadingBars oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _ReadingSkeleton extends StatelessWidget {
  const _ReadingSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(
              child: Container(
                height: 100,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            if (i == 0) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 12),
      Container(
        height: 250,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    ],
  );
}
