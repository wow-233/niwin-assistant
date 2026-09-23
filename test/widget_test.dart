import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_schedule/data/schedule_store.dart';
import 'package:shiguang_schedule/main.dart';

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
}
