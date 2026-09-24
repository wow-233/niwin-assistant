import 'dart:io';

import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/period_time.dart';

class CalendarExportResult {
  const CalendarExportResult({required this.count, required this.calendarName});
  final int count;
  final String calendarName;
}

class CalendarService {
  const CalendarService._();
  static const _channel = MethodChannel('app.shiguang/calendar');

  static Future<CalendarExportResult> exportCourses({
    required List<Course> courses,
    required DateTime semesterStart,
    required List<PeriodTime> periods,
    required int reminderMinutes,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android 系统日历');
    }
    final events = <Map<String, Object>>[];
    for (final course in courses) {
      if (course.startSection < 1 || course.endSection > periods.length) {
        continue;
      }
      final startParts = periods[course.startSection - 1].start.split(':');
      final endParts = periods[course.endSection - 1].end.split(':');
      for (final week in course.weeks) {
        if (course.cancelledWeeks.contains(week)) {
          continue;
        }
        final day = semesterStart.add(
          Duration(days: (week - 1) * 7 + course.weekday - 1),
        );
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          int.tryParse(startParts.first) ?? 8,
          int.tryParse(startParts.length > 1 ? startParts[1] : '') ?? 0,
        );
        final end = DateTime(
          day.year,
          day.month,
          day.day,
          int.tryParse(endParts.first) ?? 9,
          int.tryParse(endParts.length > 1 ? endParts[1] : '') ?? 0,
        );
        events.add({
          'title': course.name,
          'location': course.location,
          'description':
              '[泥win助手:${course.id}:$week]${course.teacher.isEmpty ? '' : '\n教师：${course.teacher}'}',
          'start': start.millisecondsSinceEpoch,
          'end': end.millisecondsSinceEpoch,
          'reminderMinutes': reminderMinutes,
        });
      }
    }
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'replaceCourseEvents',
      {'events': events},
    );
    return CalendarExportResult(
      count: (result?['count'] as num?)?.toInt() ?? 0,
      calendarName: result?['calendarName']?.toString() ?? '系统日历',
    );
  }
}
