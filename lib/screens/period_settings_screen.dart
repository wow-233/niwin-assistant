import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../models/period_time.dart';

class PeriodSettingsScreen extends StatelessWidget {
  const PeriodSettingsScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('作息时间'),
          actions: [
            TextButton(
              onPressed: () => _reset(context),
              child: const Text('恢复预设'),
            ),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: store.periodTimes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final period = store.periodTimes[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                child: Row(
                  children: [
                    CircleAvatar(child: Text('${index + 1}')),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _TimeButton(
                        label: '上课',
                        value: period.start,
                        onTap: () => _pick(context, index, true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    Expanded(
                      child: _TimeButton(
                        label: '下课',
                        value: period.end,
                        onTap: () => _pick(context, index, false),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, int index, bool start) async {
    final old = store.periodTimes[index];
    final value = start ? old.start : old.end;
    final parts = value.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      helpText: start ? '第 ${index + 1} 节上课时间' : '第 ${index + 1} 节下课时间',
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await store.setPeriodTime(
      index,
      PeriodTime(
        start: start ? formatted : old.start,
        end: start ? old.end : formatted,
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复 13 节预设？'),
        content: const Text('当前自定义作息会被替换。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.resetPeriodTimes();
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
