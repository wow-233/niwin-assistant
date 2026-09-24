import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/homework.dart';
import '../models/period_time.dart';

class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.scheduledCourses,
    required this.scheduledHomework,
    required this.exact,
    this.error,
  });
  final int scheduledCourses;
  final int scheduledHomework;
  final bool exact;
  final String? error;
  int get total => scheduledCourses + scheduledHomework;
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<NotificationScheduleResult> _queue = Future.value(
    const NotificationScheduleResult(
      scheduledCourses: 0,
      scheduledHomework: 0,
      exact: false,
    ),
  );

  Future<void> initialize() async {
    if (_ready || !Platform.isAndroid) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_niwin'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return false;
    final granted = await _android?.requestNotificationsPermission() ?? false;
    if (granted) {
      try {
        await _android?.requestExactAlarmsPermission();
      } catch (_) {
        // Inexact alarms remain available when the user declines.
      }
    }
    return granted;
  }

  Future<void> showTestNotification() async {
    await initialize();
    if (!_ready) return;
    await _plugin.show(
      id: 990001,
      title: '泥win助手',
      body: '通知权限正常；课程提醒会按设置提前发送',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_reminders_v2',
          '提醒测试',
          channelDescription: '用于确认通知权限和提醒功能',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_niwin',
        ),
      ),
    );
  }

  Future<NotificationScheduleResult> rescheduleAll({
    required bool enabled,
    required List<Homework> homework,
    required List<Course> courses,
    required DateTime semesterStart,
    required List<PeriodTime> periods,
    required int courseReminderMinutes,
  }) {
    final homeworkSnapshot = List<Homework>.of(homework);
    final courseSnapshot = List<Course>.of(courses);
    Future<NotificationScheduleResult> run() => _performReschedule(
      enabled: enabled,
      homework: homeworkSnapshot,
      courses: courseSnapshot,
      semesterStart: semesterStart,
      periods: List<PeriodTime>.of(periods),
      courseReminderMinutes: courseReminderMinutes,
    );
    _queue = _queue.then((_) => run(), onError: (_) => run());
    return _queue;
  }

  Future<NotificationScheduleResult> _performReschedule({
    required bool enabled,
    required List<Homework> homework,
    required List<Course> courses,
    required DateTime semesterStart,
    required List<PeriodTime> periods,
    required int courseReminderMinutes,
  }) async {
    await initialize();
    if (!_ready) {
      return const NotificationScheduleResult(
        scheduledCourses: 0,
        scheduledHomework: 0,
        exact: false,
        error: '通知服务未初始化',
      );
    }
    await _plugin.cancelAllPendingNotifications();
    if (!enabled) {
      return const NotificationScheduleResult(
        scheduledCourses: 0,
        scheduledHomework: 0,
        exact: false,
      );
    }
    var exact = false;
    try {
      exact = await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {}
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 120));
    final courseJobs = <_NotificationJob>[];
    final homeworkJobs = <_NotificationJob>[];

    for (final course in courses) {
      if (course.startSection < 1 || course.startSection > periods.length) {
        continue;
      }
      final parts = periods[course.startSection - 1].start.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      for (final week in course.weeks) {
        if (course.cancelledWeeks.contains(week)) {
          continue;
        }
        final day = semesterStart.add(
          Duration(days: (week - 1) * 7 + course.weekday - 1),
        );
        final startsAt = DateTime(day.year, day.month, day.day, hour, minute);
        final reminderAt = startsAt.subtract(
          Duration(minutes: courseReminderMinutes),
        );
        if (!reminderAt.isAfter(now) || reminderAt.isAfter(horizon)) {
          continue;
        }
        courseJobs.add(
          _NotificationJob(
            id: _stableId('course-${course.id}-$week'),
            when: reminderAt,
            title: courseReminderMinutes == 0
                ? '现在上课'
                : '还有 $courseReminderMinutes 分钟上课',
            body:
                '${course.name}${course.location.isEmpty ? '' : ' · ${course.location}'}',
            payload: 'course:${course.id}',
            channelId: 'course_reminders_v2',
            channelName: '课程提醒',
          ),
        );
      }
    }
    courseJobs.sort((a, b) => a.when.compareTo(b.when));
    for (final item in homework) {
      if (item.completed ||
          !item.reminderEnabled ||
          !item.dueAt.isAfter(now) ||
          item.dueAt.isAfter(horizon)) {
        continue;
      }
      homeworkJobs.add(
        _NotificationJob(
          id: _stableId('homework-${item.id}'),
          when: item.dueAt,
          title: item.courseName.isEmpty ? '待办提醒' : item.courseName,
          body: item.title,
          payload: 'homework:${item.id}',
          channelId: 'homework_reminders_v2',
          channelName: '作业与待办提醒',
        ),
      );
    }
    homeworkJobs.sort((a, b) => a.when.compareTo(b.when));

    var courseCount = 0;
    var homeworkCount = 0;
    String? error;
    for (final job in courseJobs.take(150)) {
      try {
        await _schedule(job, exact: exact);
        courseCount++;
      } catch (cause) {
        error ??= cause.toString();
      }
    }
    for (final job in homeworkJobs.take(40)) {
      try {
        await _schedule(job, exact: exact);
        homeworkCount++;
      } catch (cause) {
        error ??= cause.toString();
      }
    }
    return NotificationScheduleResult(
      scheduledCourses: courseCount,
      scheduledHomework: homeworkCount,
      exact: exact,
      error: error,
    );
  }

  Future<void> _schedule(_NotificationJob job, {required bool exact}) {
    return _plugin.zonedSchedule(
      id: job.id,
      title: job.title,
      body: job.body,
      payload: job.payload,
      scheduledDate: tz.TZDateTime.from(job.when, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          job.channelId,
          job.channelName,
          channelDescription: '泥win助手的本地课程与待办提醒',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_niwin',
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _NotificationJob {
  const _NotificationJob({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
    required this.channelId,
    required this.channelName,
  });
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String payload;
  final String channelId;
  final String channelName;
}
