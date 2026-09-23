import 'dart:io';

import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import '../services/background_service.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('课表外观')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (store.backgroundPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(store.backgroundPath!),
                        fit: BoxFit.cover,
                        cacheWidth: 960,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Colors.black12),
                      ),
                      ColoredBox(
                        color: Theme.of(context).colorScheme.surface
                            .withValues(alpha: 1 - store.backgroundOpacity),
                      ),
                      const Center(child: Text('背景预览')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('课表背景图片'),
                    subtitle: Text(
                      store.backgroundPath == null ? '未设置' : '已使用本机图片',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pickBackground(context),
                  ),
                  if (store.backgroundPath != null) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.hide_image_outlined),
                      title: const Text('移除背景'),
                      onTap: () => store.setBackground(null),
                    ),
                  ],
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on_rounded),
                    title: const Text('液态玻璃'),
                    subtitle: const Text('半透明面板与背景模糊'),
                    value: store.glassEffect,
                    onChanged: store.setGlassEffect,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.location_on_outlined),
                    title: const Text('显示上课地点'),
                    subtitle: const Text('在周课表课程块中显示教室'),
                    value: store.showCourseLocation,
                    onChanged: store.setShowCourseLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SliderCard(
              label: '背景可见度',
              value: store.backgroundOpacity,
              min: 0,
              max: 0.8,
              display: '${(store.backgroundOpacity * 100).round()}%',
              onChanged: store.setBackgroundOpacity,
            ),
            _SliderCard(
              label: '每节高度',
              value: store.cellHeight,
              min: 46,
              max: 110,
              display: '${store.cellHeight.round()} dp',
              onChanged: store.setCellHeight,
            ),
            _SliderCard(
              label: '课程块透明度',
              value: store.courseOpacity,
              min: 0.25,
              max: 1,
              display: '${(store.courseOpacity * 100).round()}%',
              onChanged: store.setCourseOpacity,
            ),
            _SliderCard(
              label: '课程块圆角',
              value: store.courseRadius,
              min: 0,
              max: 28,
              display: '${store.courseRadius.round()} dp',
              onChanged: store.setCourseRadius,
            ),
            _SliderCard(
              label: '课程块间距 / 宽度',
              value: store.courseGap,
              min: 0,
              max: 10,
              display: '${store.courseGap.round()} dp',
              onChanged: store.setCourseGap,
            ),
            _SliderCard(
              label: '课程文字大小',
              value: store.courseTextScale,
              min: 0.75,
              max: 1.5,
              display: '${(store.courseTextScale * 100).round()}%',
              onChanged: store.setCourseTextScale,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackground(BuildContext context) async {
    try {
      final path = await BackgroundService.pickAndCopy();
      if (path != null) await store.setBackground(path);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('无法使用这张图片：$error')));
    }
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(display, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
