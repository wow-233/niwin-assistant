class CountdownItem {
  const CountdownItem({
    required this.id,
    required this.title,
    required this.targetDate,
  });

  final String id;
  final String title;
  final DateTime targetDate;

  int daysFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'targetDate': targetDate.toIso8601String(),
  };

  factory CountdownItem.fromJson(Map<String, dynamic> json) => CountdownItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    targetDate: DateTime.parse(json['targetDate'] as String),
  );
}
