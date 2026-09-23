class PeriodTime {
  const PeriodTime({required this.start, required this.end});

  final String start;
  final String end;

  Map<String, String> toJson() => {'start': start, 'end': end};

  factory PeriodTime.fromJson(Map<String, dynamic> json) => PeriodTime(
    start: json['start']?.toString() ?? '08:00',
    end: json['end']?.toString() ?? '08:40',
  );

  static const defaults = <PeriodTime>[
    PeriodTime(start: '08:20', end: '09:00'),
    PeriodTime(start: '09:05', end: '09:45'),
    PeriodTime(start: '10:10', end: '10:50'),
    PeriodTime(start: '10:55', end: '11:35'),
    PeriodTime(start: '11:40', end: '12:20'),
    PeriodTime(start: '13:30', end: '14:10'),
    PeriodTime(start: '14:15', end: '14:55'),
    PeriodTime(start: '15:20', end: '16:00'),
    PeriodTime(start: '16:05', end: '16:45'),
    PeriodTime(start: '16:50', end: '17:30'),
    PeriodTime(start: '18:30', end: '19:10'),
    PeriodTime(start: '19:15', end: '19:55'),
    PeriodTime(start: '20:00', end: '20:40'),
  ];
}
