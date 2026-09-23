class Homework {
  const Homework({
    required this.id,
    required this.title,
    required this.dueAt,
    this.courseId,
    this.courseName = '',
    this.note = '',
    this.reminderEnabled = true,
    this.completed = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? courseId;
  final String courseName;
  final String note;
  final DateTime dueAt;
  final bool reminderEnabled;
  final bool completed;
  final DateTime? createdAt;

  Homework copyWith({
    String? title,
    String? courseId,
    bool clearCourse = false,
    String? courseName,
    String? note,
    DateTime? dueAt,
    bool? reminderEnabled,
    bool? completed,
  }) {
    return Homework(
      id: id,
      title: title ?? this.title,
      courseId: clearCourse ? null : (courseId ?? this.courseId),
      courseName: courseName ?? this.courseName,
      note: note ?? this.note,
      dueAt: dueAt ?? this.dueAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'courseId': courseId,
    'courseName': courseName,
    'note': note,
    'dueAt': dueAt.toIso8601String(),
    'reminderEnabled': reminderEnabled,
    'completed': completed,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] as String,
      title: json['title'] as String,
      courseId: json['courseId'] as String?,
      courseName: json['courseName'] as String? ?? '',
      note: json['note'] as String? ?? '',
      dueAt: DateTime.parse(json['dueAt'] as String),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      completed: json['completed'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );
  }
}
