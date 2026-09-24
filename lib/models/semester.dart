import 'course.dart';

class Semester {
  const Semester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    required this.courses,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final int totalWeeks;
  final List<Course> courses;

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    int? totalWeeks,
    List<Course>? courses,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      courses: courses ?? this.courses,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'totalWeeks': totalWeeks,
    'courses': courses.map((course) => course.toJson()).toList(),
  };

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名学期',
      startDate: DateTime.parse(json['startDate'].toString()),
      totalWeeks: (json['totalWeeks'] as num?)?.toInt().clamp(1, 30) ?? 20,
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .map(
            (item) => Course.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
