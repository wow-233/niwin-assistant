import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingStats {
  const ReadingStats({
    required this.readDays,
    required this.totalSeconds,
    required this.dailySeconds,
    required this.cachedAt,
  });

  final int readDays;
  final int totalSeconds;
  final Map<DateTime, int> dailySeconds;
  final DateTime cachedAt;

  String get durationLabel {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return hours > 0 ? '$hours 小时 $minutes 分钟' : '$minutes 分钟';
  }
}

class WereadService {
  WereadService._();

  static final instance = WereadService._();
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'wereadApiKey';
  static const _cacheKey = 'wereadStatsCache.v1';
  static const _cacheTimeKey = 'wereadStatsCacheTime.v1';
  static const _cacheDuration = Duration(hours: 6);

  Future<bool> hasApiKey() async =>
      (await _storage.read(key: _keyName))?.isNotEmpty == true;

  Future<String?> maskedApiKey() async {
    final value = await _storage.read(key: _keyName);
    if (value == null || value.length < 9) return null;
    return '${value.substring(0, 5)}••••${value.substring(value.length - 4)}';
  }

  Future<void> saveApiKey(String value) async {
    final key = value.trim();
    if (!key.startsWith('wrk-') || key.length < 10) {
      throw const FormatException('API Key 应以 wrk- 开头');
    }
    await _storage.write(key: _keyName, value: key);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyName);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cacheKey);
    await preferences.remove(_cacheTimeKey);
  }

  Future<ReadingStats> getMonthlyStats({bool force = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final cachedRaw = preferences.getString(_cacheKey);
    final cachedAt = DateTime.tryParse(
      preferences.getString(_cacheTimeKey) ?? '',
    );
    if (!force &&
        cachedRaw != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return _parse(cachedRaw, cachedAt);
    }

    final key = await _storage.read(key: _keyName);
    if (key == null || key.isEmpty) throw StateError('请先填写微信读书 API Key');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(
        Uri.parse('https://i.weread.qq.com/api/agent/gateway'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.write(
        jsonEncode({
          'api_name': '/readdata/detail',
          'mode': 'monthly',
          'baseTime': 0,
          'skill_version': '1.0.4',
        }),
      );
      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('请求失败（${response.statusCode}）');
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map && (decoded['errcode'] as num? ?? 0) != 0) {
        throw StateError(decoded['errmsg']?.toString() ?? '微信读书返回错误');
      }
      final now = DateTime.now();
      final stats = _parse(raw, now);
      await preferences.setString(_cacheKey, raw);
      await preferences.setString(_cacheTimeKey, now.toIso8601String());
      return stats;
    } finally {
      client.close(force: true);
    }
  }

  ReadingStats _parse(String raw, DateTime cachedAt) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('阅读统计格式错误');
    final map = Map<String, dynamic>.from(decoded);
    final rawTimes = map['readTimes'];
    final daily = <DateTime, int>{};
    if (rawTimes is Map) {
      for (final entry in rawTimes.entries) {
        final seconds = int.tryParse(entry.value.toString()) ?? 0;
        final timestamp = int.tryParse(entry.key.toString());
        if (timestamp != null) {
          daily[DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)] =
              seconds;
        }
      }
    }
    return ReadingStats(
      readDays:
          int.tryParse(map['readDays']?.toString() ?? '') ??
          daily.values.where((value) => value > 0).length,
      totalSeconds:
          int.tryParse(map['totalReadTime']?.toString() ?? '') ??
          daily.values.fold(0, (sum, value) => sum + value),
      dailySeconds: daily,
      cachedAt: cachedAt,
    );
  }
}
