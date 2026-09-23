import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../models/homework.dart';

Future<Homework?> showHomeworkEditor(
  BuildContext context, {
  required ScheduleStore store,
  Homework? homework,
  String? initialCourseId,
}) {
  return showModalBottomSheet<Homework>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _HomeworkEditor(
      store: store,
      homework: homework,
      initialCourseId: initialCourseId,
    ),
  );
}

class _HomeworkEditor extends StatefulWidget {
  const _HomeworkEditor({
    required this.store,
    this.homework,
    this.initialCourseId,
  });

  final ScheduleStore store;
  final Homework? homework;
  final String? initialCourseId;

  @override
  State<_HomeworkEditor> createState() => _HomeworkEditorState();
}

class _HomeworkEditorState extends State<_HomeworkEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _customCourse;
  late DateTime _dueAt;
  late bool _reminder;
  String? _courseId;

  @override
  void initState() {
    super.initState();
    final item = widget.homework;
    _title = TextEditingController(text: item?.title ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _customCourse = TextEditingController(
      text: item != null && item.courseId == null ? item.courseName : '',
    );
    _dueAt = item?.dueAt ?? _defaultDueAt();
    _reminder = item?.reminderEnabled ?? widget.store.notificationsEnabled;
    _courseId = item?.courseId ?? widget.initialCourseId;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _customCourse.dispose();
    super.dispose();
  }

  DateTime _defaultDueAt() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.homework == null ? '记一项作业' : '编辑作业',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('选课程，也可以作为普通随记'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('关联课程', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: const Text('自定义'),
                      selected: _courseId == null,
                      onSelected: (_) => setState(() => _courseId = null),
                    ),
                    for (final course in widget.store.courses) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(course.name),
                        selected: _courseId == course.id,
                        onSelected: (_) =>
                            setState(() => _courseId = course.id),
                      ),
                    ],
                  ],
                ),
              ),
              if (_courseId == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customCourse,
                  decoration: const InputDecoration(
                    labelText: '自定义分类（可选）',
                    hintText: '例如：社团、生活、Limbus Company',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '要完成什么？',
                  hintText: '例如：完成第三章习题',
                  prefixIcon: Icon(Icons.task_alt_rounded),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '写点内容再保存吧' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '补充说明（可选）',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: '${_dueAt.month}月${_dueAt.day}日',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule_rounded,
                      label:
                          '${_dueAt.hour.toString().padLeft(2, '0')}:${_dueAt.minute.toString().padLeft(2, '0')}',
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('到期提醒'),
                subtitle: Text(
                  widget.store.notificationsEnabled ? '到点发送系统通知' : '总提醒已在设置中关闭',
                ),
                value: _reminder && widget.store.notificationsEnabled,
                onChanged: widget.store.notificationsEnabled
                    ? (value) => setState(() => _reminder = value)
                    : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.done_rounded),
                  label: Text(widget.homework == null ? '添加到作业' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final course = _courseId == null
        ? null
        : widget.store.courses
              .where((item) => item.id == _courseId)
              .firstOrNull;
    final old = widget.homework;
    Navigator.pop(
      context,
      Homework(
        id: old?.id ?? 'homework-${DateTime.now().microsecondsSinceEpoch}',
        title: _title.text.trim(),
        courseId: course?.id,
        courseName: course?.name ?? _customCourse.text.trim(),
        note: _note.text.trim(),
        dueAt: _dueAt,
        reminderEnabled: _reminder && widget.store.notificationsEnabled,
        completed: old?.completed ?? false,
        createdAt: old?.createdAt ?? DateTime.now(),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 9),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
