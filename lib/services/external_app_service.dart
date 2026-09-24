import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalAppService {
  const ExternalAppService._();
  static const _channel = MethodChannel('app.shiguang/external_apps');
  static final _quzhiRepository = Uri.parse(
    'https://github.com/wzk-chi/quzhi-lite',
  );

  static Future<bool> openQuzhiLite() async {
    try {
      final opened = await _channel.invokeMethod<bool>('launchPackage', {
        'package': 'com.quzhi.lite',
      });
      if (opened == true) return true;
    } on PlatformException {
      // Fall through to the upstream project page.
    }
    return launchUrl(_quzhiRepository, mode: LaunchMode.externalApplication);
  }
}
