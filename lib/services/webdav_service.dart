import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const webDavUserAgent = 'NiwinAssistant/1.5.1 WebDAV/1.0';

class WebDavConfig {
  const WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
  });
  final String url;
  final String username;
  final String password;
  bool get isComplete =>
      Uri.tryParse(url)?.hasScheme == true &&
      username.isNotEmpty &&
      password.isNotEmpty;
}

class WebDavService {
  WebDavService._();
  static final instance = WebDavService._();
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'webdav.url.v1';
  static const _userKey = 'webdav.username.v1';
  static const _passwordKey = 'webdav.password.v1';

  Future<WebDavConfig> loadConfig() async => WebDavConfig(
    url: await _storage.read(key: _urlKey) ?? '',
    username: await _storage.read(key: _userKey) ?? '',
    password: await _storage.read(key: _passwordKey) ?? '',
  );

  Future<void> saveConfig(WebDavConfig config) async {
    final uri = Uri.tryParse(config.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('请输入完整的 HTTPS WebDAV 文件地址');
    }
    if (config.username.isEmpty || config.password.isEmpty) {
      throw const FormatException('请填写 WebDAV 用户名和密码（或应用密码）');
    }
    await Future.wait([
      _storage.write(key: _urlKey, value: config.url),
      _storage.write(key: _userKey, value: config.username),
      _storage.write(key: _passwordKey, value: config.password),
    ]);
  }

  Future<DateTime> upload(WebDavConfig config, String json) async {
    await _request(config, 'PUT', body: json);
    return DateTime.now();
  }

  Future<String> download(WebDavConfig config) async {
    final response = await _request(config, 'GET');
    return response;
  }

  Future<String> _request(
    WebDavConfig config,
    String method, {
    String? body,
  }) async {
    if (!config.isComplete) throw const WebDavException('请先完整填写 WebDAV 配置');
    final uri = Uri.parse(config.url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      );
      request.headers.set(HttpHeaders.userAgentHeader, webDavUserAgent);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.headers.contentLength = utf8.encode(body).length;
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebDavException(
          'WebDAV 返回 HTTP ${response.statusCode}${text.isEmpty ? '' : '：${_short(text)}'}',
        );
      }
      return text;
    } on SocketException {
      throw const WebDavException('无法连接 WebDAV 服务器');
    } on TimeoutException {
      throw const WebDavException('WebDAV 请求超时');
    } finally {
      client.close(force: true);
    }
  }

  static String _short(String value) =>
      value.length > 120 ? '${value.substring(0, 120)}…' : value;
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;
  @override
  String toString() => message;
}
