import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_schedule/models/course.dart';
import 'package:shiguang_schedule/models/period_time.dart';
import 'package:shiguang_schedule/services/zhengfang_parser.dart';

void main() {
  group('Course.parseWeeks', () {
    test('parses ranges and parity', () {
      expect(Course.parseWeeks('1-8周(单)'), {1, 3, 5, 7});
      expect(Course.parseWeeks('2-8周（双）'), {2, 4, 6, 8});
      expect(Course.parseWeeks('1-3,5,7-8周'), {1, 2, 3, 5, 7, 8});
    });

    test('formats contiguous ranges', () {
      expect(Course.formatWeeks({1, 2, 3, 5, 7, 8}), '1-3,5,7-8周');
    });
  });

  test('parses a typical Zhengfang timetable item', () {
    final courses = ZhengfangParser.parsePortalItems([
      {
        'name': '高等数学 A',
        'text': '高等数学 A\n教师：张老师\n1-16周\n第3-4节\n教室：南校2-101',
        'day': 2,
        'startSection': 3,
        'sectionCount': 2,
      },
    ]);

    expect(courses, hasLength(1));
    expect(courses.single.name, '高等数学 A');
    expect(courses.single.teacher, '张老师');
    expect(courses.single.location, '南校2-101');
    expect(courses.single.weekday, 2);
    expect(courses.single.startSection, 3);
    expect(courses.single.endSection, 4);
    expect(courses.single.weeks, hasLength(16));
    expect(courses.single.source, 'wzu');
  });

  test('normalizes imported location labels without losing the room', () {
    final courses = ZhengfangParser.parsePortalItems([
      {
        'name': '大学英语',
        'day': 4,
        'startSection': 3,
        'sectionCount': 2,
        'weeksText': '1-16周',
        'location': '📍 上课地点：南校区南9-B302 教师：徐老师',
      },
    ]);
    expect(courses.single.location, '南校区南9-B302');
  });

  test('does not invent weekday or section for ambiguous imports', () {
    final courses = ZhengfangParser.parsePortalItems([
      {'name': '无法定位的课程', 'text': '无法定位的课程\n教师：张老师\n1-16周'},
    ]);
    expect(courses, isEmpty);
  });

  test('does not invent all-semester weeks when import omits weeks', () {
    final courses = ZhengfangParser.parsePortalItems([
      {'name': '周次缺失课程', 'day': 3, 'startSection': 1, 'sectionCount': 2},
    ]);
    expect(courses, isEmpty);
  });

  test('course badge survives local JSON round-trip', () {
    const course = Course(
      id: 'water-course',
      name: '轻松课程',
      weekday: 1,
      startSection: 1,
      sectionCount: 2,
      weeks: {1, 2},
      badge: '水',
    );
    expect(Course.fromJson(course.toJson()).badge, '水');
  });

  test('contains the requested 13-period preset', () {
    expect(PeriodTime.defaults, hasLength(13));
    expect(PeriodTime.defaults.first.start, '08:20');
    expect(PeriodTime.defaults.first.end, '09:00');
    expect(PeriodTime.defaults[9].start, '16:50');
    expect(PeriodTime.defaults.last.start, '20:00');
    expect(PeriodTime.defaults.last.end, '20:40');
  });
}
