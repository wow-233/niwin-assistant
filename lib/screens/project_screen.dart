import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, this.showRecommendationsFirst = false});

  static final Uri repository = Uri.parse(
    'https://github.com/wow-233/niwin-assistant',
  );
  static final Uri email = Uri.parse(
    'mailto:wufengqianyue@qq.com?subject=%E6%B3%A5win%E5%8A%A9%E6%89%8B%E9%A1%B9%E7%9B%AE',
  );

  final bool showRecommendationsFirst;

  @override
  Widget build(BuildContext context) {
    final intro = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '泥win助手',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('本地优先的温大课表、作业随记和校园快捷工具。数据默认保存在设备中。'),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code_rounded),
                title: const Text('GitHub 项目'),
                subtitle: Text(repository.toString()),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () =>
                    launchUrl(repository, mode: LaunchMode.externalApplication),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('项目联系'),
                subtitle: const Text('wufengqianyue@qq.com'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => launchUrl(email),
              ),
            ],
          ),
        ),
      ),
    ];
    final recommendations = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Text(
          '项目推荐与参考',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      for (final item in const [
        (
          '拾光课程表',
          '开源、可扩展的多平台课程表',
          'https://github.com/XingHeYuZhuan/shiguangschedule',
        ),
        (
          'Sleepy',
          'Material You、本地优先与多教务协议',
          'https://github.com/lingion/sleepy',
        ),
        ('下节啥课', '多教务解析和课表管理参考', 'https://github.com/baoozak/timetable'),
        (
          '微信读书 Skills',
          '官方阅读统计与书架 API Skill',
          'https://github.com/Tencent/WeChatReading',
        ),
      ])
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(item.$1),
            subtitle: Text(item.$2),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => launchUrl(
              Uri.parse(item.$3),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(showRecommendationsFirst ? '项目推荐' : '关于项目')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: showRecommendationsFirst
            ? [...recommendations, const SizedBox(height: 16), ...intro]
            : [...intro, const SizedBox(height: 16), ...recommendations],
      ),
    );
  }
}
