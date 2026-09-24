class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.title,
    required this.detail,
    required this.createdAt,
    required this.icon,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime createdAt;
  final String icon;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'detail': detail,
    'createdAt': createdAt.toIso8601String(),
    'icon': icon,
  };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    detail: json['detail']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    icon: json['icon']?.toString() ?? 'history',
  );
}
