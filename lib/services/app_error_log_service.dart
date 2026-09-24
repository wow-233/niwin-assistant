import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppErrorLogService {
  AppErrorLogService._();

  static const _key = 'lastAppError.v1';
  static SharedPreferences? _preferences;

  static void attach(SharedPreferences preferences) {
    _preferences = preferences;
  }

  static String? get lastError => _preferences?.getString(_key);

  static Future<void> record(Object error, StackTrace? stack) async {
    final preferences = _preferences;
    if (preferences == null) return;
    final payload = const JsonEncoder.withIndent('  ').convert({
      'time': DateTime.now().toIso8601String(),
      'error': _limit(error.toString(), 1600),
      'stack': _limit(stack?.toString() ?? '', 6000),
    });
    try {
      await preferences.setString(_key, payload);
    } catch (_) {
      // Error reporting must never create a second application error.
    }
  }

  static Future<void> clear() async {
    try {
      await _preferences?.remove(_key);
    } catch (_) {}
  }

  static String _limit(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);
}
