import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../models/activity_entry.dart';

class ActivityTimelineScreen extends StatelessWidget {
  const ActivityTimelineScreen({super.key, required this.store});
  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('操作时间线'),
          actions: [
            if (store.activity.isNotEmpty)
              IconButton(
                tooltip: '清空记录',
                onPressed: () => _clear(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
          ],
        ),
        body: store.activity.isEmpty
            ? const Center(
                child: Text(
                  '还没有记录\n添加、修改或导入课程后会显示在这里',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: store.activity.length,
                itemBuilder: (context, index) {
                  final item = store.activity[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CircleAvatar(
                          radius: 20,
                          child: Icon(_icon(item), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: ListTile(
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${item.detail}\n${_date(item.createdAt)}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  IconData _icon(ActivityEntry item) => switch (item.icon) {
    'course' => Icons.event_note_rounded,
    'delete' => Icons.delete_outline_rounded,
    'cancel' => Icons.event_busy_outlined,
    'restore' => Icons.restore_rounded,
    'sync' => Icons.sync_rounded,
    'semester' => Icons.school_outlined,
    _ => Icons.history_rounded,
  };

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空时间线？'),
        content: const Text('只会清空操作记录，不影响课程和作业。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.clearActivity();
  }
}
