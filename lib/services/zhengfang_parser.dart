import '../models/course.dart';

class ZhengfangParser {
  const ZhengfangParser._();

  static List<Course> parsePortalItems(List<dynamic> rawItems) {
    final courses = <Course>[];
    final fingerprints = <String>{};
    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final text = _clean(item['text']?.toString() ?? '');
      final lines = text
          .split(RegExp(r'[\n\r]+'))
          .map(_clean)
          .where((line) => line.isNotEmpty)
          .toList();

      final name = _firstNonEmpty([
        item['name']?.toString(),
        ...lines.where((line) => !_isMetadata(line)),
      ]);
      if (name.isEmpty || name.length > 80) continue;

      final weekday = _weekday(item, text);
      final section = _sections(item, text);
      if (weekday == null || section == null) continue;

      final weeksText = _firstNonEmpty([
        item['weeksText']?.toString(),
        ...lines.where((line) => line.contains('周')),
      ]);
      if (weeksText.isEmpty) continue;
      final weeks = Course.parseWeeks(weeksText);
      // Accuracy first: a missing week field must not silently become 1-20.
      if (weeks.isEmpty) continue;
      final teacher = _field(
        item['teacher']?.toString(),
        lines,
        RegExp(r'(?:教师|老师|主讲)\s*[:：]?\s*(.+)'),
      );
      final location = _field(
        item['location']?.toString(),
        lines,
        RegExp(r'(?:上课地点|地点|教室)\s*[:：]?\s*(.+)'),
      );

      final fingerprint = [
        name,
        weekday,
        section.$1,
        section.$2,
        location,
        Course.formatWeeks(weeks),
      ].join('|');
      if (!fingerprints.add(fingerprint)) continue;

      final color = name.codeUnits.fold<int>(0, (sum, code) => sum + code) % 8;
      courses.add(
        Course(
          id: 'wzu-${fingerprint.hashCode.abs()}-$index',
          name: name,
          teacher: teacher,
          location: location,
          weekday: weekday,
          startSection: section.$1,
          sectionCount: section.$2,
          weeks: weeks,
          colorIndex: color,
          source: 'wzu',
        ),
      );
    }
    return courses;
  }

  static int? _weekday(Map<String, dynamic> item, String text) {
    final explicit = int.tryParse(item['day']?.toString() ?? '');
    if (explicit != null && explicit >= 1 && explicit <= 7) return explicit;
    final value = '${item['dayLabel'] ?? ''} $text';
    const labels = {
      '周一': 1,
      '星期一': 1,
      '周二': 2,
      '星期二': 2,
      '周三': 3,
      '星期三': 3,
      '周四': 4,
      '星期四': 4,
      '周五': 5,
      '星期五': 5,
      '周六': 6,
      '星期六': 6,
      '周日': 7,
      '周天': 7,
      '星期日': 7,
      '星期天': 7,
    };
    for (final entry in labels.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static (int, int)? _sections(Map<String, dynamic> item, String text) {
    final start = int.tryParse(item['startSection']?.toString() ?? '');
    final count = int.tryParse(item['sectionCount']?.toString() ?? '');
    if (start != null && start >= 1 && start <= 13) {
      return (start, (count ?? 1).clamp(1, 13 - start + 1));
    }
    final sectionText = '${item['sectionsText'] ?? ''} $text';
    final range = RegExp(r'(?:第)?\s*(\d{1,2})\s*[-~至—]\s*(\d{1,2})\s*节')
        .firstMatch(sectionText);
    if (range != null) {
      final first = int.parse(range.group(1)!);
      final last = int.parse(range.group(2)!);
      if (first >= 1 && last >= first && last <= 13) {
        return (first, last - first + 1);
      }
    }
    final single = RegExp(r'(?:第)?\s*(\d{1,2})\s*节').firstMatch(sectionText);
    if (single != null) {
      final value = int.parse(single.group(1)!);
      if (value >= 1 && value <= 13) return (value, 1);
    }
    return null;
  }

  static String _field(String? explicit, List<String> lines, RegExp pattern) {
    final direct = _clean(explicit ?? '');
    if (direct.isNotEmpty) return direct;
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) return _clean(match.group(1) ?? '');
    }
    return '';
  }

  static bool _isMetadata(String value) {
    return value.contains('周') ||
        value.contains('节') ||
        RegExp(r'^(?:教师|老师|主讲|地点|教室|上课地点)\s*[:：]').hasMatch(value);
  }

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final cleaned = _clean(value ?? '');
      if (cleaned.isNotEmpty) return cleaned;
    }
    return '';
  }

  static String _clean(String value) {
    return value
        .replaceAll(RegExp(r'[\u00a0\t]+'), ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }
}
