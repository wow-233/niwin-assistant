import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/period_time.dart';

const courseColors = <Color>[
  Color(0xFF2E8B74),
  Color(0xFF4078C0),
  Color(0xFF8667B7),
  Color(0xFFE07A5F),
  Color(0xFFB17635),
  Color(0xFF3C8DAD),
  Color(0xFFB35C8B),
  Color(0xFF5D7B3B),
];

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.week,
    required this.semesterStart,
    required this.courses,
    required this.showWeekends,
    required this.onCourseTap,
    required this.periods,
    this.onEmptyCellTap,
    this.cellHeight = 68,
    this.courseOpacity = .9,
    this.courseRadius = 10,
    this.courseGap = 2,
    this.courseTextScale = 1,
    this.showLocation = true,
  });

  static const double timeWidth = 58;

  final int week;
  final DateTime semesterStart;
  final List<Course> courses;
  final bool showWeekends;
  final ValueChanged<Course> onCourseTap;
  final List<PeriodTime> periods;
  final void Function(int weekday, int section)? onEmptyCellTap;
  final double cellHeight;
  final double courseOpacity;
  final double courseRadius;
  final double courseGap;
  final double courseTextScale;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final dayCount = showWeekends ? 7 : 5;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = (constraints.maxWidth - timeWidth) / dayCount;
                return Row(
                  children: [
                    const SizedBox(width: timeWidth),
                    for (var day = 1; day <= dayCount; day++)
                      SizedBox(
                        width: dayWidth,
                        child: _DayHeading(
                          date: semesterStart.add(
                            Duration(days: (week - 1) * 7 + day - 1),
                          ),
                          weekday: day,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: periods.length * cellHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth = (constraints.maxWidth - timeWidth) / dayCount;
                final displayed = courses
                    .where((course) => course.weekday <= dayCount)
                    .toList();
                return Stack(
                  children: [
                    for (var row = 0; row < periods.length; row++)
                      Positioned(
                        top: row * cellHeight,
                        left: 0,
                        right: 0,
                        height: cellHeight,
                        child: Row(
                          children: [
                            SizedBox(
                              width: timeWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${row + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${periods[row].start}\n${periods[row].end}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 7.5,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var day = 0; day < dayCount; day++)
                              SizedBox(
                                width: dayWidth,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onEmptyCellTap == null
                                        ? null
                                        : () =>
                                              onEmptyCellTap!(day + 1, row + 1),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: .28),
                                            width: .5,
                                          ),
                                          top: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: .28),
                                            width: .5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    for (final course in displayed)
                      Positioned(
                        left:
                            timeWidth +
                            (course.weekday - 1) * dayWidth +
                            courseGap,
                        top: (course.startSection - 1) * cellHeight + courseGap,
                        width: dayWidth - courseGap * 2,
                        height:
                            course.sectionCount * cellHeight - courseGap * 2,
                        child: _CourseCard(
                          course: course,
                          week: week,
                          opacity: courseOpacity,
                          radius: courseRadius,
                          textScale: courseTextScale,
                          showLocation: showLocation,
                          onTap: () => onCourseTap(course),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.date, required this.weekday});

  final DateTime date;
  final int weekday;

  @override
  Widget build(BuildContext context) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final today =
        now.year == date.year && now.month == date.month && now.day == date.day;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          names[weekday - 1],
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: today ? Theme.of(context).colorScheme.primary : null,
            fontWeight: today ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: today
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${date.month}/${date.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: today ? Theme.of(context).colorScheme.onPrimary : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.opacity,
    required this.radius,
    required this.textScale,
    required this.showLocation,
    required this.week,
  });

  final Course course;
  final VoidCallback onTap;
  final double opacity;
  final double radius;
  final double textScale;
  final bool showLocation;
  final int week;

  @override
  Widget build(BuildContext context) {
    final baseColor = courseColors[course.colorIndex % courseColors.length];
    final cancelled = course.cancelledWeeks.contains(week);
    final active = course.weeks.contains(week) && !cancelled;
    final allOdd =
        course.weeks.length > 1 && course.weeks.every((value) => value.isOdd);
    final allEven =
        course.weeks.length > 1 && course.weeks.every((value) => value.isEven);
    final statusBadge = cancelled
        ? '删'
        : active && course.badge.isNotEmpty
        ? course.badge
        : allOdd
        ? '单'
        : allEven
        ? '双'
        : active
        ? ''
        : '非';
    final color = active ? baseColor : const Color(0xFF727780);
    final effectiveOpacity = active ? opacity : .56;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: effectiveOpacity),
                color.withValues(alpha: (effectiveOpacity - .14).clamp(.15, 1)),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .32)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 48;
              final showRoom =
                  showLocation &&
                  course.location.isNotEmpty &&
                  constraints.maxHeight >= 48;
              return ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          course.name,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5 * textScale,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            decoration: cancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (showRoom) ...[
                          const SizedBox(height: 2),
                          Text(
                            course.location,
                            textAlign: TextAlign.center,
                            maxLines: constraints.maxHeight >= 76 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .88),
                              fontSize: 8.5 * textScale,
                              height: 1.08,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (statusBadge.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 15),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            statusBadge,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: color,
                              fontSize: 7.5 * textScale,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
