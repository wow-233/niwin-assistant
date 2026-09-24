import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_schedule/data/schedule_store.dart';
import 'package:shiguang_schedule/main.dart';
import 'package:shiguang_schedule/models/course.dart';
import 'package:shiguang_schedule/models/period_time.dart';
import 'package:shiguang_schedule/widgets/schedule_grid.dart';

void main() {
  testWidgets('empty timetable exposes today and schedule entry points', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = ScheduleStore(await SharedPreferences.getInstance());
    await store.load();

    await tester.pumpWidget(ShiguangApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('点课表格子添加课程'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);

    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsWidgets);
    expect(find.text('今天没有课程'), findsOneWidget);
  });

  testWidgets('compact schedule cards do not overflow and show week labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final course = Course(
      id: 'odd',
      name: '名字很长也不能溢出的课程',
      location: '南校区南9-B302',
      weekday: 1,
      startSection: 1,
      sectionCount: 1,
      weeks: {1, 3, 5, 7},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            week: 2,
            semesterStart: DateTime(2026, 9, 7),
            courses: [course],
            showWeekends: false,
            onCourseTap: (_) {},
            periods: PeriodTime.defaults,
            cellHeight: 38,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('单'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            week: 3,
            semesterStart: DateTime(2026, 9, 7),
            courses: [
              course.copyWith(cancelledWeeks: {3}),
            ],
            showWeekends: false,
            onCourseTap: (_) {},
            periods: PeriodTime.defaults,
            cellHeight: 38,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('删'), findsOneWidget);
  });
}
