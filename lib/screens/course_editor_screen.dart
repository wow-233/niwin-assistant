import 'package:flutter/material.dart';

import '../models/course.dart';
import '../widgets/glass_panel.dart';
import '../widgets/schedule_grid.dart';

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({
    super.key,
    this.course,
    required this.currentWeek,
    this.initialWeekday,
    this.initialStartSection,
    this.initialWeeks,
    this.initialBadge,
  });

  final Course? course;
  final int currentWeek;
  final int? initialWeekday;
  final int? initialStartSection;
  final String? initialWeeks;
  final String? initialBadge;

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _teacher;
  late final TextEditingController _location;
  late final TextEditingController _badge;
  late final TextEditingController _weeks;
  late int _weekday;
  late int _start;
  late int _end;
  late int _color;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _name = TextEditingController(text: course?.name ?? '');
    _teacher = TextEditingController(text: course?.teacher ?? '');
    _location = TextEditingController(text: course?.location ?? '');
    _badge = TextEditingController(
      text: course?.badge ?? widget.initialBadge ?? '',
    );
    _weeks = TextEditingController(
      text: course == null
          ? widget.initialWeeks ?? '1-20周'
          : Course.formatWeeks(course.weeks),
    );
    _weekday = course?.weekday ?? widget.initialWeekday ?? 1;
    _start = course?.startSection ?? widget.initialStartSection ?? 1;
    _end = course?.endSection ?? (_start + 1).clamp(1, 13);
    _color = course?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _teacher.dispose();
    _location.dispose();
    _badge.dispose();
    _weeks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.course == null ? '添加课程' : '编辑课程'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: AuroraBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: widget.course == null,
                        decoration: const InputDecoration(
                          labelText: '课程名称',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入课程名称'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _teacher,
                        decoration: const InputDecoration(
                          labelText: '教师（可选）',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: '教室（可选）',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _badge,
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: '课程角标（可选）',
                          hintText: '例如：水、重修、实验',
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          suffixIcon: TextButton(
                            onPressed: () {
                              _badge.text = _badge.text.trim() == '水'
                                  ? ''
                                  : '水';
                              setState(() {});
                            },
                            child: Text(
                              _badge.text.trim() == '水' ? '取消水课' : '标为水课',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('星期', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            ChoiceChip(
                              label: Text('周${'一二三四五六日'[day - 1]}'),
                              selected: _weekday == day,
                              onSelected: (_) => setState(() => _weekday = day),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('节次', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _start,
                              decoration: const InputDecoration(
                                labelText: '开始',
                              ),
                              items: [
                                for (var section = 1; section <= 13; section++)
                                  DropdownMenuItem(
                                    value: section,
                                    child: Text('第 $section 节'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _start = value;
                                  if (_end < _start) _end = _start;
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('至'),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(_start),
                              initialValue: _end < _start ? _start : _end,
                              decoration: const InputDecoration(
                                labelText: '结束',
                              ),
                              items: [
                                for (
                                  var section = _start;
                                  section <= 13;
                                  section++
                                )
                                  DropdownMenuItem(
                                    value: section,
                                    child: Text('第 $section 节'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => _end = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _weeks,
                        decoration: const InputDecoration(
                          labelText: '上课周次',
                          hintText: '例如：1-16周、1-15周(单)',
                          prefixIcon: Icon(Icons.date_range_rounded),
                        ),
                        validator: (value) =>
                            Course.parseWeeks(value ?? '').isEmpty
                            ? '请输入有效周次，例如 1-16周'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      Text('颜色', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          for (
                            var index = 0;
                            index < courseColors.length;
                            index++
                          )
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => _color = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: courseColors[index],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _color == index
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                        : Colors.white,
                                    width: _color == index ? 3 : 1,
                                  ),
                                ),
                                child: _color == index
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 19,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final original = widget.course;
    Navigator.of(context).pop(
      Course(
        id: original?.id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        teacher: _teacher.text.trim(),
        location: _location.text.trim(),
        badge: _badge.text.trim(),
        weekday: _weekday,
        startSection: _start,
        sectionCount: _end - _start + 1,
        weeks: Course.parseWeeks(_weeks.text),
        cancelledWeeks: original?.cancelledWeeks ?? {},
        colorIndex: _color,
        source: original?.source ?? 'manual',
      ),
    );
  }
}
