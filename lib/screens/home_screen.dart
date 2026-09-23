import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../models/course.dart';
import '../models/countdown_item.dart';
import '../models/homework.dart';
import '../models/quick_link.dart';
import '../services/notification_service.dart';
import '../services/weread_service.dart';
import '../widgets/schedule_grid.dart';
import 'course_editor_screen.dart';
import 'browser_screen.dart';
import 'homework_editor_sheet.dart';
import 'misc_screen.dart';
import 'project_screen.dart';
import 'settings_screen.dart';
import 'wzu_sync_screen.dart';
import 'weread_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 1;
  late final String _sessionEgg;
  bool _startupApplied = false;

  ScheduleStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _sessionEgg = _eggForSession();
    store.addListener(_applyStartupTab);
    _applyStartupTab();
  }

  void _applyStartupTab() {
    if (!store.isLoaded || _startupApplied || !mounted) return;
    _startupApplied = true;
    setState(() => _index = store.startupTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDueReminder());
  }

  @override
  void dispose() {
    store.removeListener(_applyStartupTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (!store.isLoaded) return const _StartupSkeleton();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: _AppBackground(
            store: store,
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _index,
                children: [
                  _TodayPage(
                    store: store,
                    eggText: _sessionEgg,
                    onAddHomework: _addHomework,
                    onAddCountdown: _addCountdown,
                    onCourseTap: (course) => _showCourse(course),
                    onOpenSchedule: () => setState(() => _index = 1),
                  ),
                  _SchedulePage(
                    store: store,
                    onSync: _syncFromWzu,
                    onAddCourse: () => _editCourse(),
                    onEmptyCellTap: (weekday, section, onlyWeek) => _editCourse(
                      weekday: weekday,
                      startSection: section,
                      onlyWeek: onlyWeek,
                    ),
                    onCourseTap: (course, week) =>
                        _showCourse(course, week: week),
                  ),
                  _HomeworkPage(
                    store: store,
                    onAdd: _addHomework,
                    onEdit: (item) => _addHomework(homework: item),
                  ),
                  _ProfilePage(
                    store: store,
                    onSync: _syncFromWzu,
                    onOpenSettings: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsScreen(store: store),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => _editCourse(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('课程'),
                )
              : _index == 2
              ? FloatingActionButton.extended(
                  onPressed: _addHomework,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('记作业'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda_rounded),
                label: '今日',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week_rounded),
                label: '课表',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt_rounded),
                label: '作业',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: '我的',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _syncFromWzu() async {
    final result = await Navigator.of(context).push<WzuSyncResult>(
      MaterialPageRoute(
        builder: (_) => WzuSyncScreen(
          initialWeek: store.weekFor(DateTime.now()).clamp(1, 25),
        ),
      ),
    );
    if (result == null) return;
    await store.setCurrentWeek(result.currentWeek);
    await store.replaceImported(result.courses);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已同步 ${result.courses.length} 门课程')));
  }

  void _showDueReminder() {
    if (!mounted || !store.notificationsEnabled) return;
    final deadline = DateTime.now().add(const Duration(hours: 24));
    final due = store.pendingHomework
        .where((item) => item.reminderEnabled && item.dueAt.isBefore(deadline))
        .firstOrNull;
    if (due == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('作业提醒：${due.title}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => setState(() => _index = 2),
        ),
      ),
    );
  }

  Future<void> _editCourse({
    Course? course,
    int? weekday,
    int? startSection,
    int? onlyWeek,
  }) async {
    final result = await Navigator.of(context).push<Course>(
      MaterialPageRoute(
        builder: (_) => CourseEditorScreen(
          course: course,
          currentWeek: store.weekFor(DateTime.now()).clamp(1, 25),
          initialWeekday: weekday,
          initialStartSection: startSection,
          initialWeeks: onlyWeek == null ? null : '$onlyWeek周',
          initialBadge: onlyWeek == null ? null : '临',
        ),
      ),
    );
    if (result == null) return;
    if (onlyWeek != null && course != null) {
      await store.cancelCourseForWeek(course.id, onlyWeek);
      await store.saveCourse(
        result.copyWith(
          id: 'change-${DateTime.now().microsecondsSinceEpoch}',
          weeks: {onlyWeek},
          cancelledWeeks: {},
          badge: '改',
          source: 'manual',
        ),
      );
    } else if (onlyWeek != null) {
      await store.saveCourse(
        result.copyWith(
          weeks: {onlyWeek},
          badge: result.badge.isEmpty ? '临' : result.badge,
        ),
      );
    } else {
      await store.saveCourse(result);
    }
  }

  Future<void> _addHomework({Homework? homework, String? courseId}) async {
    final result = await showHomeworkEditor(
      context,
      store: store,
      homework: homework,
      initialCourseId: courseId,
    );
    if (result != null) await store.saveHomework(result);
  }

  Future<void> _addCountdown() async {
    final title = TextEditingController();
    DateTime target = DateTime.now().add(const Duration(days: 30));
    final result = await showDialog<CountdownItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加倒计时'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：期末考试',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('目标日期'),
                subtitle: Text('${target.year}-${target.month}-${target.day}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: target,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setDialogState(() => target = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  CountdownItem(
                    id: 'countdown-${DateTime.now().microsecondsSinceEpoch}',
                    title: title.text.trim(),
                    targetDate: target,
                  ),
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (result != null) await store.saveCountdown(result);
  }

  Future<void> _showCourse(Course course, {int? week}) async {
    final targetWeek = week ?? store.weekFor(DateTime.now()).clamp(1, 25);
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
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          courseColors[course.colorIndex % courseColors.length],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      course.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailLine(
                icon: Icons.schedule_rounded,
                text:
                    '周${'一二三四五六日'[course.weekday - 1]} · 第${course.startSection}-${course.endSection}节'
                    '${course.endSection <= store.periodTimes.length ? ' · ${store.periodTimes[course.startSection - 1].start}-${store.periodTimes[course.endSection - 1].end}' : ''}',
              ),
              _DetailLine(
                icon: Icons.calendar_month_outlined,
                text: Course.formatWeeks(course.weeks),
              ),
              if (course.teacher.isNotEmpty)
                _DetailLine(icon: Icons.person_outline, text: course.teacher),
              if (course.location.isNotEmpty)
                _DetailLine(
                  icon: Icons.location_on_outlined,
                  text: course.location,
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(context, 'homework'),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('给这门课记作业'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'cancel-week'),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text('第 $targetWeek 周停课'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除整学期课程'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'homework') {
      await _addHomework(courseId: course.id);
    } else if (action == 'edit') {
      final scope = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text('只修改第 $targetWeek 周'),
                subtitle: const Text('原课程保留，本周显示“改”角标'),
                onTap: () => Navigator.pop(context, 'week'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('修改整学期'),
                onTap: () => Navigator.pop(context, 'semester'),
              ),
            ],
          ),
        ),
      );
      if (scope == 'week') {
        await _editCourse(course: course, onlyWeek: targetWeek);
      } else if (scope == 'semester') {
        await _editCourse(course: course);
      }
    } else if (action == 'cancel-week') {
      await store.cancelCourseForWeek(course.id, targetWeek);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已将第 $targetWeek 周标记为停课')));
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除这门课程？'),
          content: Text(course.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed == true) await store.deleteCourse(course.id);
    }
  }
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    required this.store,
    required this.onAddHomework,
    required this.onAddCountdown,
    required this.onCourseTap,
    required this.onOpenSchedule,
    required this.eggText,
  });

  final ScheduleStore store;
  final VoidCallback onAddHomework;
  final VoidCallback onAddCountdown;
  final ValueChanged<Course> onCourseTap;
  final VoidCallback onOpenSchedule;
  final String eggText;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = store.weekFor(now);
    final courses = store
        .coursesForWeek(week)
        .where((course) => course.weekday == now.weekday)
        .toList();
    final pending = store.pendingHomework.take(3).toList();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: const Text('今日'),
          actions: [
            IconButton(
              tooltip: '添加倒计时',
              onPressed: onAddCountdown,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            IconButton(
              tooltip: '记作业',
              onPressed: onAddHomework,
              icon: const Icon(Icons.edit_note_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              _DateHero(
                month: '${now.month}月',
                day: now.day.toString().padLeft(2, '0'),
                detail:
                    '${week > 0 ? '第 $week 周' : '假期中'} · ${weekdays[now.weekday - 1]}',
                courseCount: courses.length,
              ),
              if (store.easterEggEnabled) ...[
                const SizedBox(height: 10),
                _EasterEggCard(text: eggText),
              ],
              if (store.countdowns.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: store.countdowns.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = store.countdowns[index];
                      final days = item.daysFrom(now);
                      return SizedBox(
                        width: 156,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onLongPress: () => store.deleteCountdown(item.id),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    days == 0 ? '就是今天' : '还有 $days 天',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeader(
                title: '今天的课程',
                action: '完整课表',
                onTap: onOpenSchedule,
              ),
              const SizedBox(height: 10),
              if (courses.isEmpty)
                _EmptyCard(
                  icon: Icons.wb_sunny_outlined,
                  title: '今天没有课程',
                  subtitle: '暂无课程安排',
                )
              else
                for (final course in courses)
                  _TodayCourseCard(
                    course: course,
                    startTime: course.startSection <= store.periodTimes.length
                        ? store.periodTimes[course.startSection - 1].start
                        : '待定',
                    endTime: course.endSection <= store.periodTimes.length
                        ? store.periodTimes[course.endSection - 1].end
                        : '待定',
                    showLocation: store.showCourseLocation,
                    onTap: () => onCourseTap(course),
                  ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: '待完成',
                action: '${store.pendingHomework.length} 项',
              ),
              const SizedBox(height: 10),
              if (pending.isEmpty)
                _EmptyCard(
                  icon: Icons.done_all_rounded,
                  title: '暂无待办',
                  subtitle: '点右上角添加',
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < pending.length; i++) ...[
                        _HomeworkRow(item: pending[i], store: store),
                        if (i != pending.length - 1)
                          const Divider(height: 1, indent: 58),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchedulePage extends StatefulWidget {
  const _SchedulePage({
    required this.store,
    required this.onSync,
    required this.onAddCourse,
    required this.onEmptyCellTap,
    required this.onCourseTap,
  });

  final ScheduleStore store;
  final VoidCallback onSync;
  final VoidCallback onAddCourse;
  final void Function(int weekday, int section, int? onlyWeek) onEmptyCellTap;
  final void Function(Course course, int week) onCourseTap;

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  late int _week;
  bool _adjustMode = false;

  @override
  void initState() {
    super.initState();
    _week = widget.store.weekFor(DateTime.now()).clamp(1, 25);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final monday = store.dateFor(_week, 1);
    final sunday = store.dateFor(_week, 7);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _jumpToWeek,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '第 $_week 周',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                        Text(
                          '${monday.month}月${monday.day}日 – ${sunday.month}月${sunday.day}日',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '上一周',
                onPressed: _week > 1 ? () => setState(() => _week--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: '下一周',
                onPressed: _week < 25 ? () => setState(() => _week++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: _adjustMode ? '退出本周调整' : '调整当前周',
                onPressed: () => setState(() => _adjustMode = !_adjustMode),
                color: _adjustMode
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: Icon(
                  _adjustMode
                      ? Icons.edit_calendar_rounded
                      : Icons.edit_calendar_outlined,
                ),
              ),
              IconButton(
                tooltip: '同步课表',
                onPressed: widget.onSync,
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
        ),
        if (store.courses.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.touch_app_outlined),
                title: const Text('点课表格子添加课程'),
                subtitle: const Text('也可以使用右上角同步教务课表'),
                trailing: TextButton(
                  onPressed: widget.onSync,
                  child: const Text('同步'),
                ),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rawFitHeight =
                  (constraints.maxHeight - 62) / store.periodTimes.length;
              final canFit = rawFitHeight >= 38;
              final fitHeight = rawFitHeight.clamp(38.0, store.cellHeight);
              final grid = ScheduleGrid(
                week: _week,
                semesterStart: store.semesterStart,
                courses: store.coursesForWeek(_week),
                showWeekends: store.showWeekends,
                onCourseTap: (course) => widget.onCourseTap(course, _week),
                periods: store.periodTimes,
                onEmptyCellTap: (weekday, section) => widget.onEmptyCellTap(
                  weekday,
                  section,
                  _adjustMode ? _week : null,
                ),
                cellHeight: store.fitScheduleToScreen
                    ? fitHeight
                    : store.cellHeight,
                courseOpacity: store.courseOpacity,
                courseRadius: store.courseRadius,
                courseGap: store.courseGap,
                courseTextScale: store.courseTextScale,
                showLocation: store.showCourseLocation,
              );
              return GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300 && _week < 25) {
                    setState(() => _week++);
                  } else if (velocity > 300 && _week > 1) {
                    setState(() => _week--);
                  }
                },
                child: Card(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  clipBehavior: Clip.antiAlias,
                  child: store.fitScheduleToScreen && canFit
                      ? grid
                      : SingleChildScrollView(child: grid),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _jumpToWeek() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 25,
          itemBuilder: (context, index) {
            final week = index + 1;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context, week),
              child: Ink(
                decoration: BoxDecoration(
                  color: week == _week
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text('$week')),
              ),
            );
          },
        ),
      ),
    );
    if (selected != null) setState(() => _week = selected);
  }
}

class _HomeworkPage extends StatefulWidget {
  const _HomeworkPage({
    required this.store,
    required this.onAdd,
    required this.onEdit,
  });

  final ScheduleStore store;
  final VoidCallback onAdd;
  final ValueChanged<Homework> onEdit;

  @override
  State<_HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<_HomeworkPage> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final items =
        widget.store.homework
            .where((item) => _showCompleted ? item.completed : !item.completed)
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          pinned: true,
          title: const Text('作业与随记'),
          actions: [
            IconButton(
              tooltip: _showCompleted ? '查看待完成' : '查看已完成',
              onPressed: () => setState(() => _showCompleted = !_showCompleted),
              icon: Icon(
                _showCompleted
                    ? Icons.inbox_outlined
                    : Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          sliver: SliverToBoxAdapter(
            child: _HomeworkOverview(items: widget.store.homework),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: items.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _EmptyCard(
                      icon: _showCompleted
                          ? Icons.archive_outlined
                          : Icons.edit_note_rounded,
                      title: _showCompleted ? '还没有完成记录' : '暂无待完成作业',
                      subtitle: _showCompleted
                          ? '完成的作业会收进这里。'
                          : '快捷选择课程，几秒钟记下新作业。',
                      action: _showCompleted ? null : '记第一项',
                      onTap: _showCompleted ? null : widget.onAdd,
                    ),
                  ),
                )
              : SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _HomeworkCard(
                      item: item,
                      store: widget.store,
                      onEdit: () => widget.onEdit(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HomeworkOverview extends StatelessWidget {
  const _HomeworkOverview({required this.items});

  final List<Homework> items;

  @override
  Widget build(BuildContext context) {
    final completed = items.where((item) => item.completed).length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('完成进度', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('待完成 ${total - completed} · 已完成 $completed · 共 $total'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.store,
    required this.onSync,
    required this.onOpenSettings,
  });

  final ScheduleStore store;
  final VoidCallback onSync;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(pinned: true, title: Text('我的')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          'win',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '泥win助手',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${store.courses.length} 门课程 · ${store.pendingHomework.length} 项待办',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '快捷',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text('常用网页', style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 78,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final link in store.quickLinks)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: SizedBox(
                          width: 126,
                          child: Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openQuick(context, link),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      link.webVpn
                                          ? Icons.vpn_lock_rounded
                                          : Icons.language_rounded,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        link.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 78,
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _addQuick(context),
                          child: const Center(child: Icon(Icons.add_rounded)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (store.wereadEnabled) ...[
                const SizedBox(height: 10),
                _ReadingSummaryTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReadingStatsScreen(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('导入温大课表'),
                    subtitle: const Text('手动登录、打开课表并提取'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onSync,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('外观与课表设置'),
                    subtitle: Text(
                      store.customFontName == null
                          ? 'Material You · 系统字体'
                          : 'Material You · ${store.customFontName}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onOpenSettings,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('课程和待办提醒'),
                    subtitle: const Text('使用 Android 本地通知'),
                    value: store.notificationsEnabled,
                    onChanged: (value) => _toggleNotifications(context, value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.casino_outlined),
                    title: const Text('杂物'),
                    subtitle: Text('转盘 · 已打开 ${store.appOpenCount} 次'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MiscScreen(store: store),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('实验性功能'),
                    subtitle: const Text('微信读书统计等可选功能'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExperimentalScreen(store: store),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('关于项目'),
                    subtitle: const Text('GitHub、联系邮箱与项目说明'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProjectScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.recommend_outlined),
                    title: const Text('项目推荐'),
                    subtitle: const Text('开源课表与微信读书工具'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const ProjectScreen(showRecommendationsFirst: true),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openQuick(BuildContext context, QuickLink link) async {
    if (link.webVpn) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WebVpnInputScreen(store: store),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserScreen(
          initialUrl: link.url,
          title: link.title,
          store: store,
        ),
      ),
    );
  }

  Future<void> _addQuick(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserScreen(
          initialUrl: 'https://rz.wzu.edu.cn/',
          title: '温大网页',
          store: store,
        ),
      ),
    );
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
  }
}

class _DateHero extends StatelessWidget {
  const _DateHero({
    required this.month,
    required this.day,
    required this.detail,
    required this.courseCount,
  });

  final String month;
  final String day;
  final String detail;
  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  day,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    height: .95,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Container(width: 1, height: 64, color: scheme.outlineVariant),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text('今天有 $courseCount 门课'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCourseCard extends StatelessWidget {
  const _TodayCourseCard({
    required this.course,
    required this.onTap,
    required this.startTime,
    required this.endTime,
    required this.showLocation,
  });

  final Course course;
  final VoidCallback onTap;
  final String startTime;
  final String endTime;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final color = courseColors[course.colorIndex % courseColors.length];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 7, color: color),
              SizedBox(
                width: 88,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$startTime\n$endTime',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '第${course.startSection}-${course.endSection}节',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (course.badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                course.badge,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (showLocation && course.location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${course.location}${course.teacher.isEmpty ? '' : ' · ${course.teacher}'}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingSummaryTile extends StatefulWidget {
  const _ReadingSummaryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ReadingSummaryTile> createState() => _ReadingSummaryTileState();
}

class _ReadingSummaryTileState extends State<_ReadingSummaryTile> {
  late final Future<ReadingStats> _stats = WereadService.instance
      .getMonthlyStats();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<ReadingStats>(
        future: _stats,
        builder: (context, snapshot) {
          final subtitle = snapshot.hasData
              ? '${snapshot.requireData.readDays} 天 · ${snapshot.requireData.durationLabel}'
              : snapshot.hasError
              ? '暂时无法读取，点击查看'
              : '正在读取本地缓存…';
          return ListTile(
            leading: const Icon(Icons.auto_stories_outlined),
            title: const Text('本月阅读'),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.onTap,
          );
        },
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.item,
    required this.store,
    required this.onEdit,
  });

  final Homework item;
  final ScheduleStore store;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final overdue = !item.completed && item.dueAt.isBefore(DateTime.now());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.completed,
                onChanged: (_) => store.toggleHomework(item.id),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.courseName.isNotEmpty)
                      Text(
                        item.courseName,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          overdue
                              ? Icons.error_outline_rounded
                              : Icons.schedule_rounded,
                          size: 16,
                          color: overdue
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _dueLabel(item.dueAt, overdue),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: overdue
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                        ),
                        if (item.reminderEnabled &&
                            store.notificationsEnabled) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这项作业？'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteHomework(item.id);
  }
}

class _HomeworkRow extends StatelessWidget {
  const _HomeworkRow({required this.item, required this.store});

  final Homework item;
  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: item.completed,
        onChanged: (_) => store.toggleHomework(item.id),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.courseName.isEmpty ? '随记' : item.courseName} · ${item.dueAt.month}/${item.dueAt.day}',
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onTap, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground({required this.store, required this.child});

  final ScheduleStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.surface, scheme.surfaceContainerLow],
            ),
          ),
        ),
        if (store.backgroundPath != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: store.glassEffect ? 4 : 0,
              sigmaY: store.glassEffect ? 4 : 0,
            ),
            child: Image.file(
              File(store.backgroundPath!),
              fit: BoxFit.cover,
              cacheWidth: 1440,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (store.backgroundPath != null)
          ColoredBox(
            color: scheme.surface.withValues(
              alpha: 1 - store.backgroundOpacity,
            ),
          ),
        child,
      ],
    );
  }
}

class _EasterEggCard extends StatelessWidget {
  const _EasterEggCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer
          .withValues(alpha: .78),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 19),
            const SizedBox(width: 9),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _StartupSkeleton extends StatelessWidget {
  const _StartupSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 116, height: 32, decoration: _shape(color, 12)),
              const SizedBox(height: 22),
              Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: _shape(color, 12),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 7),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Container(width: 54, decoration: _shape(color, 14)),
                    const SizedBox(width: 8),
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(child: Container(decoration: _shape(color, 16))),
                      if (i < 2) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _shape(Color color, double radius) => BoxDecoration(
    color: color.withValues(alpha: .72),
    borderRadius: BorderRadius.circular(radius),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _eggForSession() {
  const eggs = [
    'limbus company',
    '没有关水……',
    '需要打开美团就打开闪动',
    '你每天都会忘记很多事情',
    '(✧∀✧)',
    '╮(￣▽￣)╭',
    '今天也要先把最小的一件事做完。',
    '别急，截止日期还没追到这里。',
    '先去上课，世界观稍后再崩塌。',
    '食堂还是外卖？交给转盘，不交给内耗。',
    '知之为知之，不知为不知。——《论语》',
    '路漫漫其修远兮，吾将上下而求索。——屈原',
    '长风破浪会有时，直挂云帆济沧海。——李白',
    '竹杖芒鞋轻胜马，谁怕？——苏轼',
    '山重水复疑无路，柳暗花明又一村。——陆游',
    '今日宜：少想一点，多做五分钟。',
    '系统提示：你的专注力正在重新连接。',
    '作业不会消失，但可以被一个个划掉。',
    '摸鱼结束倒计时：并没有开始。(￣▽￣)／',
    '保持清醒，也允许偶尔发呆。',
    '先保存，再大胆修改。',
    '你不是忘了，只是记忆正在排队。',
    '好运加载中…… 99%',
    '(ง •̀_•́)ง 把今天推过去！',
    'ヽ(•̀ω•́ )ゝ 下节课见。',
  ];
  return eggs[Random().nextInt(eggs.length)];
}

String _dueLabel(DateTime date, bool overdue) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (overdue) return '已逾期 · ${date.month}/${date.day} $time';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;
  if (days == 0) return '今天 $time';
  if (days == 1) return '明天 $time';
  return '${date.month}月${date.day}日 $time';
}
