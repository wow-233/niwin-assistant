import 'package:flutter/material.dart';

import '../data/schedule_store.dart';
import 'roulette_screen.dart';

class MiscScreen extends StatelessWidget {
  const MiscScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('杂物')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '启动计数',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          const Text('每次真正打开应用自动加一'),
                        ],
                      ),
                    ),
                    Text(
                      '${store.appOpenCount}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.casino_outlined),
                title: const Text('选择困难转盘'),
                subtitle: const Text('吃什么、不吃食堂、外卖与自定义选项'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RouletteScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('其他'),
                subtitle: const Text('一些不常用的开关'),
                children: [
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.egg_alt_outlined),
                    title: const Text('随机文本'),
                    subtitle: const Text('每次进入应用随机换一条，不按日期固定'),
                    value: store.easterEggEnabled,
                    onChanged: store.setEasterEggEnabled,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
