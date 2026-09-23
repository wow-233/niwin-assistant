import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_schedule/models/homework.dart';

void main() {
  test('homework round-trips through local JSON', () {
    final due = DateTime(2026, 9, 23, 20);
    final item = Homework(
      id: 'h1',
      title: '完成第三章习题',
      courseId: 'math',
      courseName: '数学分析',
      note: '第 1—8 题',
      dueAt: due,
      reminderEnabled: true,
      createdAt: DateTime(2026, 9, 22),
    );

    final restored = Homework.fromJson(item.toJson());
    expect(restored.title, item.title);
    expect(restored.courseName, '数学分析');
    expect(restored.dueAt, due);
    expect(restored.reminderEnabled, isTrue);
    expect(restored.completed, isFalse);
  });
}
