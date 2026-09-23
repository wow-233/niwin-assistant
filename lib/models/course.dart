import 'dart:math' as math;

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.sectionCount,
    required this.weeks,
    this.cancelledWeeks = const {},
    this.teacher = '',
    this.location = '',
    this.badge = '',
    this.colorIndex = 0,
    this.source = 'manual',
  });

  final String id;
  final String name;
  final String teacher;
  final String location;
  final String badge;
  final int weekday;
  final int startSection;
  final int sectionCount;
  final Set<int> weeks;
  final Set<int> cancelledWeeks;
  final int colorIndex;
  final String source;

  int get endSection => startSection + sectionCount - 1;

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    String? badge,
    int? weekday,
    int? startSection,
    int? sectionCount,
    Set<int>? weeks,
    Set<int>? cancelledWeeks,
    int? colorIndex,
    String? source,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      badge: badge ?? this.badge,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      sectionCount: sectionCount ?? this.sectionCount,
      weeks: weeks ?? this.weeks,
      cancelledWeeks: cancelledWeeks ?? this.cancelledWeeks,
      colorIndex: colorIndex ?? this.colorIndex,
      source: source ?? this.source,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': location,
    'badge': badge,
    'weekday': weekday,
    'startSection': startSection,
    'sectionCount': sectionCount,
    'weeks': weeks.toList()..sort(),
    'cancelledWeeks': cancelledWeeks.toList()..sort(),
    'colorIndex': colorIndex,
    'source': source,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String? ?? '',
      location: json['location'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      weekday: json['weekday'] as int,
      startSection: json['startSection'] as int,
      sectionCount: json['sectionCount'] as int,
      weeks: (json['weeks'] as List<dynamic>).cast<int>().toSet(),
      cancelledWeeks: (json['cancelledWeeks'] as List<dynamic>? ?? const [])
          .cast<int>()
          .toSet(),
      colorIndex: json['colorIndex'] as int? ?? 0,
      source: json['source'] as String? ?? 'manual',
    );
  }

  static Set<int> parseWeeks(String input, {int fallbackMax = 20}) {
    final cleaned = input
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll('至', '-')
        .replaceAll('—', '-')
        .replaceAll('－', '-')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty || cleaned == '全周') {
      return {for (var week = 1; week <= fallbackMax; week++) week};
    }

    final result = <int>{};
    final pattern = RegExp(r'(\d+)(?:-(\d+))?周?(?:[\(（]([单双])[\)）])?');
    for (final match in pattern.allMatches(cleaned)) {
      final start = int.parse(match.group(1)!);
      final end = int.tryParse(match.group(2) ?? '') ?? start;
      final parity = match.group(3);
      for (
        var week = math.min(start, end);
        week <= math.max(start, end) && week <= 30;
        week++
      ) {
        if (parity == '单' && week.isEven) continue;
        if (parity == '双' && week.isOdd) continue;
        if (week > 0) result.add(week);
      }
    }
    return result;
  }

  static String formatWeeks(Set<int> weeks) {
    if (weeks.isEmpty) return '未设置';
    final sorted = weeks.toList()..sort();
    final parts = <String>[];
    var start = sorted.first;
    var previous = start;
    for (final week in sorted.skip(1)) {
      if (week == previous + 1) {
        previous = week;
        continue;
      }
      parts.add(start == previous ? '$start' : '$start-$previous');
      start = previous = week;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    return '${parts.join(',')}周';
  }
}
