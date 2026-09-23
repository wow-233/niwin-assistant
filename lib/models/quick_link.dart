class QuickLink {
  const QuickLink({
    required this.id,
    required this.title,
    required this.url,
    this.webVpn = false,
  });

  final String id;
  final String title;
  final String url;
  final bool webVpn;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'webVpn': webVpn,
  };

  factory QuickLink.fromJson(Map<String, dynamic> json) => QuickLink(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '快捷方式',
    url: json['url']?.toString() ?? '',
    webVpn: json['webVpn'] as bool? ?? false,
  );
}
