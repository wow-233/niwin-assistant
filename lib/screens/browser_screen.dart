import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/schedule_store.dart';
import '../models/quick_link.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.initialUrl,
    required this.store,
    this.title = '网页',
  });

  final String initialUrl;
  final String title;
  final ScheduleStore store;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  late final TextEditingController _address;
  bool _desktop = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.initialUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) =>
              mounted ? setState(() => _progress = value) : null,
          onPageStarted: (url) => _address.text = url,
          onPageFinished: (url) => _address.text = url,
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    var value = raw.trim();
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.loadRequest(uri);
  }

  Future<void> _toggleDesktop() async {
    _desktop = !_desktop;
    await _controller.setUserAgent(_desktop ? _desktopUserAgent : null);
    await _controller.reload();
    if (mounted) setState(() {});
  }

  Future<void> _saveShortcut() async {
    final title = TextEditingController(text: widget.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存到“快捷”'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, title.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    title.dispose();
    if (name == null || name.isEmpty) return;
    await widget.store.saveQuickLink(
      QuickLink(
        id: 'link-${DateTime.now().microsecondsSinceEpoch}',
        title: name,
        url: _address.text,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存到“我的 → 快捷”')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '保存快捷方式',
            onPressed: _saveShortcut,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: _desktop ? '切换手机模式' : '切换电脑模式',
            onPressed: _toggleDesktop,
            icon: Icon(
              _desktop ? Icons.phone_android_rounded : Icons.computer_rounded,
            ),
          ),
          IconButton(
            tooltip: '用外部浏览器打开',
            onPressed: () => launchUrl(
              Uri.parse(_address.text),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _address,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _open,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.language_rounded, size: 18),
                      suffixIcon: IconButton(
                        onPressed: () => _open(_address.text),
                        icon: const Icon(Icons.arrow_circle_right_outlined),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _controller.reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

class WebVpnInputScreen extends StatefulWidget {
  const WebVpnInputScreen({super.key, required this.store});

  final ScheduleStore store;

  @override
  State<WebVpnInputScreen> createState() => _WebVpnInputScreenState();
}

class _WebVpnInputScreenState extends State<WebVpnInputScreen> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Uri? _proxyUri(String raw) {
    var value = raw.trim();
    if (!value.contains('://')) value = 'https://$value';
    final source = Uri.tryParse(value);
    if (source == null || source.host.isEmpty) return null;
    if (source.host.endsWith('.webvpn.wzu.edu.cn')) return source;
    if (!source.host.endsWith('.wzu.edu.cn')) return null;
    final proxyHost =
        '${source.host.substring(0, source.host.length - '.wzu.edu.cn'.length).replaceAll('.', '-')}-443.webvpn.wzu.edu.cn';
    return source.replace(scheme: 'https', host: proxyHost, port: 443);
  }

  Future<void> _open() async {
    final target = _proxyUri(_url.text);
    if (target == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入以 wzu.edu.cn 结尾的温大链接')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserScreen(
          initialUrl: target.toString(),
          title: 'WebVPN',
          store: widget.store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebVPN 直达')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '粘贴温大网页链接',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('应用只转换访问地址；若学校要求认证，会显示官方登录页面。'),
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '原始链接',
              hintText: 'https://jwc.wzu.edu.cn/...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.vpn_lock_rounded),
            label: const Text('通过 WebVPN 访问'),
          ),
        ],
      ),
    );
  }
}
