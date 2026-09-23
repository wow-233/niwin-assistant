import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/homework.dart';
import '../models/period_time.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

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

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return false;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> showTestNotification() async {
    await initialize();
    if (!_ready) return;
    await _plugin.show(
      id: 990001,
      title: '泥win助手',
      body: '课程和待办提醒已正常工作',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_reminders',
          '提醒测试',
          channelDescription: '用于确认通知权限和提醒功能',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_niwin',
        ),
      ),
    );
  }

  Future<void> rescheduleAll({
    required bool enabled,
    required List<Homework> homework,
    required List<Course> courses,
    required DateTime semesterStart,
    required List<PeriodTime> periods,
    required int courseReminderMinutes,
  }) async {
    await initialize();
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    if (!enabled) return;

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 120));
    final pending = <Future<void>>[];
    const maxScheduled = 192;
    for (final item in homework) {
      if (item.completed ||
          !item.reminderEnabled ||
          !item.dueAt.isAfter(now) ||
          item.dueAt.isAfter(horizon) ||
          pending.length >= maxScheduled) {
        continue;
      }
      pending.add(
        _schedule(
          id: _stableId('homework-${item.id}'),
          when: item.dueAt,
          title: item.courseName.isEmpty ? '待办提醒' : item.courseName,
          body: item.title,
          payload: 'homework:${item.id}',
          channelId: 'homework_reminders',
          channelName: '作业与待办提醒',
        ),
      );
    }

    for (final course in courses) {
      if (course.startSection < 1 || course.startSection > periods.length) {
        continue;
      }
      final parts = periods[course.startSection - 1].start.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      for (final week in course.weeks) {
        if (course.cancelledWeeks.contains(week)) continue;
        final day = semesterStart.add(
          Duration(days: (week - 1) * 7 + course.weekday - 1),
        );
        final startsAt = DateTime(day.year, day.month, day.day, hour, minute);
        final reminderAt = startsAt.subtract(
          Duration(minutes: courseReminderMinutes),
        );
        if (!reminderAt.isAfter(now) ||
            reminderAt.isAfter(horizon) ||
            pending.length >= maxScheduled) {
          continue;
        }
        pending.add(
          _schedule(
            id: _stableId('course-${course.id}-$week'),
            when: reminderAt,
            title: '还有 $courseReminderMinutes 分钟上课',
            body:
                '${course.name}${course.location.isEmpty ? '' : ' · ${course.location}'}',
            payload: 'course:${course.id}',
            channelId: 'course_reminders',
            channelName: '课程提醒',
          ),
        );
      }
    }
    await Future.wait(pending);
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
    required String channelId,
    required String channelName,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: '泥win助手的本地课程与待办提醒',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_niwin',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
