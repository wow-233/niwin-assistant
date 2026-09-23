import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/countdown_item.dart';
import '../models/homework.dart';
import '../models/period_time.dart';
import '../models/quick_link.dart';
import '../services/notification_service.dart';

class ScheduleStore extends ChangeNotifier {
  ScheduleStore(this._preferences) {
    final now = DateTime.now();
    semesterStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
  }

  static const _coursesKey = 'courses.v1';
  static const _semesterStartKey = 'semesterStart.v1';
  static const _weekendsKey = 'showWeekends.v1';
  static const _glassKey = 'glassEffect.v1';
  static const _homeworkKey = 'homework.v1';
  static const _notificationsKey = 'notifications.v2';
  static const _dynamicColorKey = 'dynamicColor.v1';
  static const _themeModeKey = 'themeMode.v1';
  static const _seedColorKey = 'seedColor.v1';
  static const _fontPathKey = 'fontPath.v1';
  static const _fontFamilyKey = 'fontFamily.v1';
  static const _fontNameKey = 'fontName.v1';
  static const _periodTimesKey = 'periodTimes.v1';
  static const _courseReminderKey = 'courseReminderMinutes.v1';
  static const _backgroundPathKey = 'backgroundPath.v1';
  static const _backgroundOpacityKey = 'backgroundOpacity.v1';
  static const _cellHeightKey = 'cellHeight.v1';
  static const _courseOpacityKey = 'courseOpacity.v1';
  static const _courseRadiusKey = 'courseRadius.v1';
  static const _courseGapKey = 'courseGap.v1';
  static const _courseTextScaleKey = 'courseTextScale.v1';
  static const _easterEggKey = 'easterEgg.v1';
  static const _showCourseLocationKey = 'showCourseLocation.v1';
  static const _appOpenCountKey = 'appOpenCount.v1';
  static const _startupTabKey = 'startupTab.v1';
  static const _fitScheduleKey = 'fitScheduleToScreen.v1';
  static const _quickLinksKey = 'quickLinks.v1';
  static const _wereadEnabledKey = 'wereadEnabled.v1';
  static const _countdownsKey = 'countdowns.v1';

  final SharedPreferences _preferences;
  final List<Course> _courses = [];
  final List<Homework> _homework = [];
  final List<QuickLink> _quickLinks = [];
  final List<CountdownItem> _countdowns = [];

  List<Course> get courses => List.unmodifiable(_courses);
  List<Homework> get homework => List.unmodifiable(_homework);
  List<QuickLink> get quickLinks => List.unmodifiable(_quickLinks);
  List<CountdownItem> get countdowns => List.unmodifiable(_countdowns);
  late DateTime semesterStart;
  bool showWeekends = true;
  bool glassEffect = true;
  bool notificationsEnabled = false;
  bool useDynamicColor = true;
  String themeMode = 'system';
  int seedColorValue = 0xFF6750A4;
  String? customFontPath;
  String? customFontFamily;
  String? customFontName;
  List<PeriodTime> periodTimes = List.of(PeriodTime.defaults);
  int courseReminderMinutes = 15;
  String? backgroundPath;
  double backgroundOpacity = 0.24;
  double cellHeight = 68;
  double courseOpacity = 0.9;
  double courseRadius = 10;
  double courseGap = 2;
  double courseTextScale = 1;
  bool easterEggEnabled = true;
  bool showCourseLocation = true;
  int appOpenCount = 0;
  int startupTab = 1;
  bool fitScheduleToScreen = true;
  bool isLoaded = false;
  bool wereadEnabled = false;
  Timer? _notificationSyncTimer;

  Future<void> load() async {
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final savedStart = _preferences.getString(_semesterStartKey);
    semesterStart = savedStart == null
        ? thisMonday
        : DateTime.parse(savedStart);
    showWeekends = _preferences.getBool(_weekendsKey) ?? true;
    glassEffect = _preferences.getBool(_glassKey) ?? true;
    notificationsEnabled = _preferences.getBool(_notificationsKey) ?? false;
    useDynamicColor = _preferences.getBool(_dynamicColorKey) ?? true;
    themeMode = _preferences.getString(_themeModeKey) ?? 'system';
    seedColorValue = _preferences.getInt(_seedColorKey) ?? 0xFF6750A4;
    customFontPath = _preferences.getString(_fontPathKey);
    customFontFamily = _preferences.getString(_fontFamilyKey);
    customFontName = _preferences.getString(_fontNameKey);
    courseReminderMinutes = _preferences.getInt(_courseReminderKey) ?? 15;
    backgroundPath = _preferences.getString(_backgroundPathKey);
    if (backgroundPath != null && !File(backgroundPath!).existsSync()) {
      backgroundPath = null;
      await _preferences.remove(_backgroundPathKey);
    }
    backgroundOpacity = _preferences.getDouble(_backgroundOpacityKey) ?? 0.24;
    cellHeight = _preferences.getDouble(_cellHeightKey) ?? 68;
    courseOpacity = _preferences.getDouble(_courseOpacityKey) ?? 0.9;
    courseRadius = _preferences.getDouble(_courseRadiusKey) ?? 10;
    courseGap = _preferences.getDouble(_courseGapKey) ?? 2;
    courseTextScale = _preferences.getDouble(_courseTextScaleKey) ?? 1;
    easterEggEnabled = _preferences.getBool(_easterEggKey) ?? true;
    showCourseLocation = _preferences.getBool(_showCourseLocationKey) ?? true;
    appOpenCount = _preferences.getInt(_appOpenCountKey) ?? 0;
    startupTab = (_preferences.getInt(_startupTabKey) ?? 1).clamp(0, 1);
    fitScheduleToScreen = _preferences.getBool(_fitScheduleKey) ?? true;
    wereadEnabled = _preferences.getBool(_wereadEnabledKey) ?? false;
    final rawPeriods = _preferences.getString(_periodTimesKey);
    if (rawPeriods != null) {
      try {
        final decoded = jsonDecode(rawPeriods) as List<dynamic>;
        final parsed = decoded
            .map((item) => PeriodTime.fromJson(item as Map<String, dynamic>))
            .toList();
        if (parsed.isNotEmpty) periodTimes = parsed;
      } catch (_) {
        periodTimes = List.of(PeriodTime.defaults);
      }
    }

    final rawCourses = _preferences.getString(_coursesKey);
    if (rawCourses != null) {
      try {
        final decoded = jsonDecode(rawCourses) as List<dynamic>;
        _courses
          ..clear()
          ..addAll(
            decoded.map(
              (item) => Course.fromJson(item as Map<String, dynamic>),
            ),
          );
      } on FormatException {
        // Keep the app usable if an old/corrupt local payload is encountered.
      }
    }
    final rawHomework = _preferences.getString(_homeworkKey);
    if (rawHomework != null) {
      try {
        final decoded = jsonDecode(rawHomework) as List<dynamic>;
        _homework
          ..clear()
          ..addAll(
            decoded.map(
              (item) => Homework.fromJson(item as Map<String, dynamic>),
            ),
          );
      } on FormatException {
        // Ignore an old/corrupt payload and keep the rest of the app available.
      }
    }
    final rawQuickLinks = _preferences.getString(_quickLinksKey);
    if (rawQuickLinks != null) {
      try {
        final decoded = jsonDecode(rawQuickLinks) as List<dynamic>;
        _quickLinks
          ..clear()
          ..addAll(
            decoded.map(
              (item) =>
                  QuickLink.fromJson(Map<String, dynamic>.from(item as Map)),
            ),
          );
      } on FormatException {
        _quickLinks.clear();
      }
    }
    if (_quickLinks.isEmpty) {
      _quickLinks.add(
        const QuickLink(id: 'webvpn', title: 'WebVPN', url: '', webVpn: true),
      );
    }
    final rawCountdowns = _preferences.getString(_countdownsKey);
    if (rawCountdowns != null) {
      try {
        final decoded = jsonDecode(rawCountdowns) as List<dynamic>;
        _countdowns
          ..clear()
          ..addAll(
            decoded.map(
              (item) => CountdownItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
      } on FormatException {
        _countdowns.clear();
      }
    }
    isLoaded = true;
    notifyListeners();
  }

  List<Homework> get pendingHomework =>
      _homework.where((item) => !item.completed).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  Future<void> saveHomework(Homework item) async {
    final index = _homework.indexWhere((value) => value.id == item.id);
    if (index == -1) {
      _homework.add(item);
    } else {
      _homework[index] = item;
    }
    await _persistHomework();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> toggleHomework(String id) async {
    final index = _homework.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _homework[index] = _homework[index].copyWith(
      completed: !_homework[index].completed,
    );
    await _persistHomework();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> deleteHomework(String id) async {
    _homework.removeWhere((item) => item.id == id);
    await _persistHomework();
    _scheduleNotificationSync();
    notifyListeners();
  }

  int weekFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.difference(semesterStart).inDays ~/ 7 + 1;
  }

  DateTime dateFor(int week, int weekday) {
    return semesterStart.add(Duration(days: (week - 1) * 7 + weekday - 1));
  }

  List<Course> coursesForWeek(int week) {
    return _courses
        .where(
          (course) =>
              course.weeks.contains(week) &&
              !course.cancelledWeeks.contains(week),
        )
        .toList()
      ..sort((a, b) {
        final byDay = a.weekday.compareTo(b.weekday);
        return byDay != 0 ? byDay : a.startSection.compareTo(b.startSection);
      });
  }

  Future<void> saveCourse(Course course) async {
    final index = _courses.indexWhere((item) => item.id == course.id);
    if (index == -1) {
      _courses.add(course);
    } else {
      _courses[index] = course;
    }
    await _persistCourses();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> deleteCourse(String id) async {
    _courses.removeWhere((course) => course.id == id);
    await _persistCourses();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> cancelCourseForWeek(String id, int week) async {
    final index = _courses.indexWhere((course) => course.id == id);
    if (index == -1) return;
    final cancelled = {..._courses[index].cancelledWeeks, week};
    _courses[index] = _courses[index].copyWith(cancelledWeeks: cancelled);
    await _persistCourses();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> replaceImported(List<Course> imported) async {
    _courses.removeWhere((course) => course.source == 'wzu');
    _courses.addAll(imported);
    await _persistCourses();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> clearCourses() async {
    _courses.clear();
    await _persistCourses();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> setSemesterStart(DateTime date) async {
    semesterStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    await _preferences.setString(
      _semesterStartKey,
      semesterStart.toIso8601String(),
    );
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> setCurrentWeek(int week) async {
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    await setSemesterStart(thisMonday.subtract(Duration(days: (week - 1) * 7)));
  }

  Future<void> setShowWeekends(bool value) async {
    showWeekends = value;
    await _preferences.setBool(_weekendsKey, value);
    notifyListeners();
  }

  Future<void> setGlassEffect(bool value) async {
    glassEffect = value;
    await _preferences.setBool(_glassKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await _preferences.setBool(_notificationsKey, value);
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> setCourseReminderMinutes(int value) async {
    courseReminderMinutes = value.clamp(0, 120);
    await _preferences.setInt(_courseReminderKey, courseReminderMinutes);
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> setPeriodTime(int index, PeriodTime value) async {
    if (index < 0 || index >= periodTimes.length) return;
    periodTimes[index] = value;
    await _persistPeriods();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> resetPeriodTimes() async {
    periodTimes = List.of(PeriodTime.defaults);
    await _persistPeriods();
    _scheduleNotificationSync();
    notifyListeners();
  }

  Future<void> setBackground(String? path) async {
    final oldPath = backgroundPath;
    backgroundPath = path;
    if (path == null) {
      await _preferences.remove(_backgroundPathKey);
    } else {
      await _preferences.setString(_backgroundPathKey, path);
    }
    if (oldPath != null && oldPath != path) {
      try {
        await File(oldPath).delete();
      } on FileSystemException {
        // The previous file may already have been removed.
      }
    }
    notifyListeners();
  }

  Future<void> setBackgroundOpacity(double value) async {
    backgroundOpacity = value.clamp(0, 1);
    await _preferences.setDouble(_backgroundOpacityKey, backgroundOpacity);
    notifyListeners();
  }

  Future<void> setCellHeight(double value) async {
    cellHeight = value.clamp(46, 110);
    await _preferences.setDouble(_cellHeightKey, cellHeight);
    notifyListeners();
  }

  Future<void> setCourseOpacity(double value) async {
    courseOpacity = value.clamp(0.25, 1);
    await _preferences.setDouble(_courseOpacityKey, courseOpacity);
    notifyListeners();
  }

  Future<void> setCourseRadius(double value) async {
    courseRadius = value.clamp(0, 28);
    await _preferences.setDouble(_courseRadiusKey, courseRadius);
    notifyListeners();
  }

  Future<void> setCourseGap(double value) async {
    courseGap = value.clamp(0, 10);
    await _preferences.setDouble(_courseGapKey, courseGap);
    notifyListeners();
  }

  Future<void> setCourseTextScale(double value) async {
    courseTextScale = value.clamp(0.75, 1.5);
    await _preferences.setDouble(_courseTextScaleKey, courseTextScale);
    notifyListeners();
  }

  Future<void> setEasterEggEnabled(bool value) async {
    easterEggEnabled = value;
    await _preferences.setBool(_easterEggKey, value);
    notifyListeners();
  }

  Future<void> setShowCourseLocation(bool value) async {
    showCourseLocation = value;
    await _preferences.setBool(_showCourseLocationKey, value);
    notifyListeners();
  }

  Future<void> recordAppOpen() async {
    appOpenCount++;
    await _preferences.setInt(_appOpenCountKey, appOpenCount);
    notifyListeners();
  }

  Future<void> setStartupTab(int value) async {
    startupTab = value.clamp(0, 1);
    await _preferences.setInt(_startupTabKey, startupTab);
    notifyListeners();
  }

  Future<void> setFitScheduleToScreen(bool value) async {
    fitScheduleToScreen = value;
    await _preferences.setBool(_fitScheduleKey, value);
    notifyListeners();
  }

  Future<void> setWereadEnabled(bool value) async {
    wereadEnabled = value;
    await _preferences.setBool(_wereadEnabledKey, value);
    notifyListeners();
  }

  Future<void> saveQuickLink(QuickLink link) async {
    final index = _quickLinks.indexWhere((item) => item.id == link.id);
    if (index == -1) {
      _quickLinks.add(link);
    } else {
      _quickLinks[index] = link;
    }
    await _preferences.setString(
      _quickLinksKey,
      jsonEncode(_quickLinks.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> deleteQuickLink(String id) async {
    if (id == 'webvpn') return;
    _quickLinks.removeWhere((item) => item.id == id);
    await _preferences.setString(
      _quickLinksKey,
      jsonEncode(_quickLinks.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> saveCountdown(CountdownItem item) async {
    final index = _countdowns.indexWhere((value) => value.id == item.id);
    if (index == -1) {
      _countdowns.add(item);
    } else {
      _countdowns[index] = item;
    }
    await _persistCountdowns();
    notifyListeners();
  }

  Future<void> deleteCountdown(String id) async {
    _countdowns.removeWhere((item) => item.id == id);
    await _persistCountdowns();
    notifyListeners();
  }

  String exportBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'niwin-backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'semesterStart': semesterStart.toIso8601String(),
      'courses': _courses.map((item) => item.toJson()).toList(),
      'homework': _homework.map((item) => item.toJson()).toList(),
      'periodTimes': periodTimes.map((item) => item.toJson()).toList(),
      'countdowns': _countdowns.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> importBackupJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['format'] != 'niwin-backup') {
      throw const FormatException('不是泥win助手备份文件');
    }
    final map = Map<String, dynamic>.from(decoded);
    final courses = (map['courses'] as List<dynamic>? ?? const [])
        .map((item) => Course.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final homework = (map['homework'] as List<dynamic>? ?? const [])
        .map(
          (item) => Homework.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final periods = (map['periodTimes'] as List<dynamic>? ?? const [])
        .map(
          (item) => PeriodTime.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final countdowns = (map['countdowns'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              CountdownItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final start = DateTime.tryParse(map['semesterStart']?.toString() ?? '');
    if (start == null || periods.isEmpty) {
      throw const FormatException('备份内容不完整');
    }
    _courses
      ..clear()
      ..addAll(courses);
    _homework
      ..clear()
      ..addAll(homework);
    _countdowns
      ..clear()
      ..addAll(countdowns);
    periodTimes = periods;
    semesterStart = start;
    await Future.wait([
      _persistCourses(),
      _persistHomework(),
      _persistPeriods(),
      _persistCountdowns(),
      _preferences.setString(_semesterStartKey, start.toIso8601String()),
    ]);
    _scheduleNotificationSync();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  Future<void> setUseDynamicColor(bool value) async {
    useDynamicColor = value;
    await _preferences.setBool(_dynamicColorKey, value);
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    themeMode = value;
    await _preferences.setString(_themeModeKey, value);
    notifyListeners();
  }

  Future<void> setSeedColor(int value) async {
    seedColorValue = value;
    await _preferences.setInt(_seedColorKey, value);
    notifyListeners();
  }

  Future<void> setCustomFont({
    required String path,
    required String family,
    required String name,
  }) async {
    final oldPath = customFontPath;
    customFontPath = path;
    customFontFamily = family;
    customFontName = name;
    await _preferences.setString(_fontPathKey, path);
    await _preferences.setString(_fontFamilyKey, family);
    await _preferences.setString(_fontNameKey, name);
    if (oldPath != null && oldPath != path) {
      try {
        await File(oldPath).delete();
      } on FileSystemException {
        // The file may already have been removed by the operating system.
      }
    }
    notifyListeners();
  }

  Future<void> clearCustomFont() async {
    final oldPath = customFontPath;
    customFontPath = null;
    customFontFamily = null;
    customFontName = null;
    await _preferences.remove(_fontPathKey);
    await _preferences.remove(_fontFamilyKey);
    await _preferences.remove(_fontNameKey);
    if (oldPath != null) {
      try {
        await File(oldPath).delete();
      } on FileSystemException {
        // Missing files do not prevent switching back to the system font.
      }
    }
    notifyListeners();
  }

  Future<void> _persistCourses() {
    return _preferences.setString(
      _coursesKey,
      jsonEncode(_courses.map((course) => course.toJson()).toList()),
    );
  }

  Future<void> _persistHomework() {
    return _preferences.setString(
      _homeworkKey,
      jsonEncode(_homework.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _persistPeriods() {
    return _preferences.setString(
      _periodTimesKey,
      jsonEncode(periodTimes.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _persistCountdowns() {
    return _preferences.setString(
      _countdownsKey,
      jsonEncode(_countdowns.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _syncNotifications() {
    return NotificationService.instance.rescheduleAll(
      enabled: notificationsEnabled,
      homework: _homework,
      courses: _courses,
      semesterStart: semesterStart,
      periods: periodTimes,
      courseReminderMinutes: courseReminderMinutes,
    );
  }

  void _scheduleNotificationSync() {
    _notificationSyncTimer?.cancel();
    _notificationSyncTimer = Timer(const Duration(milliseconds: 350), () {
      _syncNotifications();
    });
  }

  @override
  void dispose() {
    _notificationSyncTimer?.cancel();
    super.dispose();
  }
}
