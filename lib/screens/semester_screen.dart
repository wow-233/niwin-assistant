import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../models/semester.dart';

class SemesterScreen extends StatelessWidget {
  const SemesterScreen({super.key, required this.store});
  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('学期管理')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('新学期'),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: store.semesters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final semester = store.semesters[index];
            final active = semester.id == store.activeSemesterId;
            return Card(
              color: active
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: active ? null : () => store.switchSemester(semester.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.school_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              semester.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_date(semester.startDate)} · ${semester.totalWeeks}周 · ${semester.courses.length}门课程',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _edit(context, semester: semester);
                          }
                          if (value == 'delete') {
                            _delete(context, semester);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          if (store.semesters.length > 1)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, {Semester? semester}) async {
    final name = TextEditingController(text: semester?.name ?? '');
    var start = semester?.startDate ?? DateTime.now();
    var weeks = semester?.totalWeeks ?? 20;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(semester == null ? '新建学期' : '编辑学期'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '学期名称'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('第一周日期'),
                  subtitle: Text(_date(start)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setDialogState(() => start = picked);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: weeks,
                  decoration: const InputDecoration(labelText: '学期周数'),
                  items: [
                    for (var value = 1; value <= 30; value++)
                      DropdownMenuItem(value: value, child: Text('$value 周')),
                  ],
                  onChanged: (value) {
                    if (value != null) weeks = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final title = name.text.trim();
    name.dispose();
    if (confirmed != true) return;
    if (semester == null) {
      await store.createSemester(
        name: title,
        startDate: start,
        totalWeeks: weeks,
      );
    } else {
      if (semester.id != store.activeSemesterId) {
        await store.switchSemester(semester.id);
      }
      await store.updateActiveSemester(
        name: title,
        startDate: start,
        totalWeeks: weeks,
      );
    }
  }

  Future<void> _delete(BuildContext context, Semester semester) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个学期？'),
        content: Text(
          '${semester.name}\n其中的 ${semester.courses.length} 门课程会一并删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteSemester(semester.id);
  }

  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
