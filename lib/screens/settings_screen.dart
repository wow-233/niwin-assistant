import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../services/backup_service.dart';
import '../services/custom_font_service.dart';
import '../services/notification_service.dart';
import '../services/calendar_service.dart';
import 'appearance_screen.dart';
import 'period_settings_screen.dart';
import 'semester_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _GroupTitle('外观'),
            _SettingsCard(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.wallpaper_rounded),
                  title: const Text('壁纸动态取色'),
                  subtitle: const Text('Android 12 及以上跟随 Material You'),
                  value: store.useDynamicColor,
                  onChanged: store.setUseDynamicColor,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.contrast_rounded),
                  title: const Text('深浅模式'),
                  subtitle: Text(_themeModeLabel(store.themeMode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickThemeMode(context),
                ),
                if (!store.useDynamicColor) ...[
                  const Divider(height: 1, indent: 56),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('主题颜色'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 13,
                          runSpacing: 12,
                          children: [
                            for (final color in _seedColors)
                              _ColorSeed(
                                color: color,
                                selected:
                                    store.seedColorValue == color.toARGB32(),
                                onTap: () =>
                                    store.setSeedColor(color.toARGB32()),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('自定义字体'),
                  subtitle: Text(store.customFontName ?? '系统默认 · 支持导入 TTF'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showFontSheet(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('课表外观'),
                  subtitle: const Text('背景、玻璃、尺寸、圆角与透明度'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppearanceScreen(store: store),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _GroupTitle('课表'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('学期管理'),
                  subtitle: Text(
                    '${store.activeSemester.name} · ${store.semesterWeeks} 周',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SemesterScreen(store: store),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导出本地备份'),
                  subtitle: const Text('课程、作业、作息与学期日期 JSON'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _exportBackup(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('从备份恢复'),
                  subtitle: const Text('恢复前会再次确认，适合换机迁移'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _importBackup(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('默认启动页面'),
                  subtitle: Text(store.startupTab == 1 ? '课表' : '今日'),
                  trailing: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('今日')),
                      ButtonSegment(value: 1, label: Text('课表')),
                    ],
                    selected: {store.startupTab},
                    onSelectionChanged: (value) =>
                        store.setStartupTab(value.first),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.fit_screen_rounded),
                  title: const Text('课表自动适应屏幕'),
                  subtitle: const Text('优先完整显示 13 节，减少上下滚动'),
                  value: store.fitScheduleToScreen,
                  onChanged: store.setFitScheduleToScreen,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('当前学期第一周'),
                  subtitle: Text(_dateLabel(store.semesterStart)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickSemesterStart(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.access_time_rounded),
                  title: const Text('作息时间'),
                  subtitle: Text('13 节 · 第1节 ${store.periodTimes.first.start}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PeriodSettingsScreen(store: store),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.weekend_outlined),
                  title: const Text('显示周末'),
                  subtitle: const Text('关闭后只显示周一至周五'),
                  value: store.showWeekends,
                  onChanged: store.setShowWeekends,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('系统提醒'),
                  subtitle: const Text('课程和待办通过通知栏提醒'),
                  value: store.notificationsEnabled,
                  onChanged: (value) => _toggleNotifications(context, value),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('课前提醒'),
                  subtitle: Text('提前 ${store.courseReminderMinutes} 分钟'),
                  trailing: SizedBox(
                    width: 76,
                    child: TextFormField(
                      initialValue: '${store.courseReminderMinutes}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '分',
                      ),
                      onFieldSubmitted: (value) {
                        final minutes = int.tryParse(value);
                        if (minutes != null) {
                          store.setCourseReminderMinutes(minutes);
                        }
                      },
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('写入系统日历'),
                  subtitle: const Text('仅写入当前学期课程，包含地点与课前提醒'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _exportCalendar(context),
                ),
                if (store.notificationsEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('检查并重建提醒'),
                    subtitle: const Text('发送测试通知并重新登记未来提醒'),
                    trailing: const Icon(Icons.send_outlined),
                    onTap: () => _testAndReschedule(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            const _GroupTitle('数据'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '清空全部课程',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('不会影响学校教务系统中的数据'),
                  onTap: () => _confirmClear(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.security_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '字体、课程与作业数据均保存在本机。登录温大时，账号密码只输入在学校官方页面。',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickThemeMode(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '深浅模式',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: store.themeMode,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                children: [
                  for (final item in const [
                    ('system', '跟随系统', Icons.brightness_auto_rounded),
                    ('light', '浅色', Icons.light_mode_outlined),
                    ('dark', '深色', Icons.dark_mode_outlined),
                  ])
                    RadioListTile<String>(
                      value: item.$1,
                      secondary: Icon(item.$3),
                      title: Text(item.$2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (value != null) await store.setThemeMode(value);
  }

  Future<void> _showFontSheet(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '自定义字体',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text('应用不内置第三方字体。可从霞鹜文楷等项目下载 TTF 文件，再从本机导入。'),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '泥win助手 Aa 123',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(store.customFontName ?? '当前使用系统默认字体'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'import'),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('从本机选择 .ttf'),
                ),
              ),
              if (store.customFontName != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'reset'),
                    child: const Text('恢复系统字体'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'reset') {
      await store.clearCustomFont();
      return;
    }
    try {
      final font = await CustomFontService.pickAndLoad();
      if (font == null) return;
      await store.setCustomFont(
        path: font.path,
        family: font.family,
        name: font.displayName,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已启用字体：${font.displayName}')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('字体导入失败：$error')));
    }
  }

  Future<void> _pickSemesterStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: store.semesterStart,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: '选择学期第一周内任意一天',
    );
    if (picked != null) await store.setSemesterStart(picked);
  }

  Future<void> _toggleNotifications(BuildContext context, bool value) async {
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        await store.setNotificationsEnabled(false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('没有通知权限，提醒未开启')));
        return;
      }
    }
    await store.setNotificationsEnabled(value);
    if (value) {
      final result = await store.rescheduleNotifications();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已登记 ${result.total} 个提醒${result.exact ? ' · 精确模式' : ' · 省电模式'}',
          ),
        ),
      );
    }
  }

  Future<void> _testAndReschedule(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await NotificationService.instance.showTestNotification();
      final result = await store.rescheduleNotifications();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.error == null
                ? '提醒正常：课程 ${result.scheduledCourses} 个，待办 ${result.scheduledHomework} 个 · ${result.exact ? '精确模式' : '省电模式'}'
                : '已登记 ${result.total} 个，部分失败：${result.error}',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('提醒检查失败：$error')));
      }
    }
  }

  Future<void> _exportCalendar(BuildContext context) async {
    if (store.courses.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前学期没有课程')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写入系统日历？'),
        content: Text(
          '将替换此前由泥win助手写入的课程事件，并写入“${store.activeSemester.name}”的有效课程。不会写入作业。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('写入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await CalendarService.exportCourses(
        courses: store.courses,
        semesterStart: store.semesterStart,
        periods: store.periodTimes,
        reminderMinutes: store.courseReminderMinutes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已向“${result.calendarName}”写入 ${result.count} 节课程'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('写入日历失败：$error')));
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部课程？'),
        content: const Text('本机中的已导入课程和手动课程都会删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.clearCourses();
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final saved = await BackupService.exportJson(store.exportBackupJson());
      if (!context.mounted || !saved) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('备份已导出')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final raw = await BackupService.importJson();
      if (raw == null || !context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复这份备份？'),
          content: const Text('当前课程、作业、作息和学期日期将被备份内容替换。'),
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
      await store.importBackupJson(raw);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('备份已恢复')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$error')));
    }
  }

  String _themeModeLabel(String mode) => switch (mode) {
    'light' => '浅色',
    'dark' => '深色',
    _ => '跟随系统',
  };

  String _dateLabel(DateTime date) => '${date.year}年${date.month}月${date.day}日';
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ColorSeed extends StatelessWidget {
  const _ColorSeed({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

const _seedColors = [
  Color(0xFF6750A4),
  Color(0xFF006A60),
  Color(0xFF0061A4),
  Color(0xFF7D5260),
  Color(0xFF825500),
  Color(0xFF984061),
];
