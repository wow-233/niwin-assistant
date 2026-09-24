import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_schedule/data/schedule_store.dart';
import 'package:shiguang_schedule/models/course.dart';

void main() {
  test(
    'semesters keep independent course collections and survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ScheduleStore(preferences);
      await store.load();
      final firstId = store.activeSemesterId;
      await store.saveCourse(
        const Course(
          id: 'first-course',
          name: '第一学期课程',
          weekday: 1,
          startSection: 1,
          sectionCount: 2,
          weeks: {1, 2},
          location: '南校区 1-101',
        ),
      );

      await store.createSemester(
        name: '新学期',
        startDate: DateTime(2027, 2, 22),
        totalWeeks: 18,
      );
      expect(store.courses, isEmpty);
      expect(store.semesterWeeks, 18);
      await store.saveCourse(
        const Course(
          id: 'second-course',
          name: '第二学期课程',
          weekday: 2,
          startSection: 3,
          sectionCount: 2,
          weeks: {1, 2},
        ),
      );
      await store.switchSemester(firstId);
      expect(store.courses.single.name, '第一学期课程');
      store.dispose();

      final restored = ScheduleStore(preferences);
      await restored.load();
      expect(restored.activeSemesterId, firstId);
      expect(restored.semesters, hasLength(2));
      expect(restored.courses.single.location, '南校区 1-101');
      restored.dispose();
    },
  );

  test('experimental features are disabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ScheduleStore(await SharedPreferences.getInstance());
    await store.load();
    expect(store.wereadEnabled, isFalse);
    expect(store.timelineEnabled, isFalse);
    expect(store.academicEnabled, isFalse);
    expect(store.showerEnabled, isFalse);
    expect(store.webDavEnabled, isFalse);
    store.dispose();
  });

  test('WebDAV timetable payload excludes non-timetable data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ScheduleStore(preferences);
    await store.load();
    await store.saveCourse(
      const Course(
        id: 'webdav-course',
        name: 'WebDAV 课程',
        weekday: 3,
        startSection: 5,
        sectionCount: 2,
        weeks: {1, 3, 5},
        location: '北校区 2-201',
      ),
    );

    final payload = store.exportTimetableJson();
    expect(payload, contains('niwin-timetable'));
    expect(payload, contains('WebDAV 课程'));
    expect(payload, isNot(contains('homework')));
    expect(payload, isNot(contains('countdowns')));
    expect(payload, isNot(contains('quickLinks')));

    final restored = ScheduleStore(preferences);
    await restored.load();
    await restored.importTimetableJson(payload);
    expect(restored.courses.single.name, 'WebDAV 课程');
    expect(restored.courses.single.location, '北校区 2-201');
    store.dispose();
    restored.dispose();
  });

  test('corrupt local payloads do not prevent startup', () async {
    SharedPreferences.setMockInitialValues({
      'semesterStart.v1': 'not-a-date',
      'courses.v1': '[{"id": 3}]',
      'homework.v1': '{broken',
      'quickLinks.v1': '[null]',
      'countdowns.v1': '[{"targetDate": false}]',
    });
    final store = ScheduleStore(await SharedPreferences.getInstance());
    await expectLater(store.load(), completes);
    expect(store.isLoaded, isTrue);
    expect(store.courses, isEmpty);
    expect(store.homework, isEmpty);
    expect(store.quickLinks.single.id, 'webvpn');
    expect(store.countdowns, isEmpty);
    store.dispose();
  });
}
