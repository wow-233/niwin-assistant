import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const quzhiUserAgent = 'NiwinAssistant/1.5.1 Android/6.5.28';

class QuzhiSession {
  const QuzhiSession({
    required this.loginCode,
    required this.v3LoginCode,
    required this.telephone,
    required this.userId,
    required this.accountId,
    required this.projectId,
    required this.name,
  });
  final String loginCode;
  final String v3LoginCode;
  final String telephone;
  final int userId;
  final int accountId;
  final int projectId;
  final String name;

  Map<String, Object> toJson() => {
    'loginCode': loginCode,
    'v3LoginCode': v3LoginCode,
    'telephone': telephone,
    'userId': userId,
    'accountId': accountId,
    'projectId': projectId,
    'name': name,
  };

  factory QuzhiSession.fromJson(Map<String, dynamic> json) => QuzhiSession(
    loginCode: json['loginCode']?.toString() ?? '',
    v3LoginCode: json['v3LoginCode']?.toString() ?? '',
    telephone: json['telephone']?.toString() ?? '',
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    accountId: (json['accountId'] as num?)?.toInt() ?? 0,
    projectId: (json['projectId'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
  );
}

class QuzhiDevice {
  const QuzhiDevice({
    required this.snCode,
    required this.name,
    this.address = '',
    this.buildingName = '',
    this.floorName = '',
    this.roomName = '',
    this.projectName = '',
    this.rssi = 0,
  });
  final String snCode;
  final String name;
  final String address;
  final String buildingName;
  final String floorName;
  final String roomName;
  final String projectName;
  final int rssi;
  String get location => [
    buildingName,
    floorName,
    roomName,
  ].where((value) => value.isNotEmpty).join();

  Map<String, Object> toJson() => {
    'snCode': snCode,
    'name': name,
    'address': address,
    'buildingName': buildingName,
    'floorName': floorName,
    'roomName': roomName,
    'projectName': projectName,
    'rssi': rssi,
  };

  factory QuzhiDevice.fromJson(Map<String, dynamic> json) => QuzhiDevice(
    snCode: json['snCode']?.toString() ?? '',
    name: json['name']?.toString() ?? '热水设备',
    address: json['address']?.toString() ?? '',
    buildingName: json['buildingName']?.toString() ?? '',
    floorName: json['floorName']?.toString() ?? '',
    roomName: json['roomName']?.toString() ?? '',
    projectName: json['projectName']?.toString() ?? '',
    rssi: (json['rssi'] as num?)?.toInt() ?? 0,
  );
}

class QuzhiActiveOrder {
  const QuzhiActiveOrder({
    required this.orderNo,
    required this.snCode,
    required this.startedAt,
  });
  final String orderNo;
  final String snCode;
  final DateTime startedAt;
  Map<String, Object> toJson() => {
    'orderNo': orderNo,
    'snCode': snCode,
    'startedAt': startedAt.toIso8601String(),
  };
  factory QuzhiActiveOrder.fromJson(Map<String, dynamic> json) =>
      QuzhiActiveOrder(
        orderNo: json['orderNo']?.toString() ?? '',
        snCode: json['snCode']?.toString() ?? '',
        startedAt:
            DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class QuzhiService {
  QuzhiService._();
  static final instance = QuzhiService._();
  static const _storage = FlutterSecureStorage();
  static const _channel = MethodChannel('app.shiguang/quzhi');
  static const _base = 'https://v3-api.china-qzxy.cn/';
  static const _version = '6.5.28';
  static const _sessionKey = 'quzhi.session.v1';
  static const _devicesKey = 'quzhi.devices.v1';
  static const _orderKey = 'quzhi.order.v1';

  Future<QuzhiSession?> loadSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return QuzhiSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(QuzhiSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _sessionKey),
      _storage.delete(key: _devicesKey),
      _storage.delete(key: _orderKey),
    ]);
  }

  Future<List<QuzhiDevice>> loadDevices() async {
    final raw = await _storage.read(key: _devicesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                QuzhiDevice.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDevice(QuzhiDevice device) async {
    final devices = await loadDevices();
    devices.removeWhere(
      (item) => item.snCode.toUpperCase() == device.snCode.toUpperCase(),
    );
    devices.insert(0, device);
    await _storage.write(
      key: _devicesKey,
      value: jsonEncode(devices.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteDevice(String snCode) async {
    final devices = await loadDevices()
      ..removeWhere((item) => item.snCode == snCode);
    await _storage.write(
      key: _devicesKey,
      value: jsonEncode(devices.map((item) => item.toJson()).toList()),
    );
  }

  Future<QuzhiActiveOrder?> loadActiveOrder() async {
    final raw = await _storage.read(key: _orderKey);
    if (raw == null) return null;
    try {
      return QuzhiActiveOrder.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> sendCode(String phone) async {
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      throw const QuzhiException('请输入 11 位手机号');
    }
    final secret = md5
        .convert(
          utf8.encode('${phone.substring(0, 3)}${phone.substring(7)}klcx'),
        )
        .toString();
    final response = await _request(
      'GET',
      'user/verification/code/get',
      query: {
        'secret': secret,
        'typeId': '3',
        'telephone': phone,
        'platform': '1',
        'phoneSystem': 'android',
        'version': _version,
      },
    );
    _requireSuccess(response, '验证码发送失败');
  }

  Future<QuzhiSession> loginSms(String phone, String code) async {
    final response = await _request(
      'POST',
      'user/registerAndLogin',
      form: {
        'type': '5',
        'telephone': phone,
        'smsCode': code,
        'phoneSystem': 'android',
        'version': _version,
      },
    );
    return _parseLogin(response);
  }

  Future<QuzhiSession> loginPassword(String phone, String password) async {
    final digest = md5.convert(utf8.encode(password)).toString().toUpperCase();
    final response = await _request(
      'POST',
      'user/login',
      form: {
        'password': digest.substring(digest.length - 10),
        'telephone': phone,
        'type': '0',
        'identifier': '',
        'phoneSystem': 'android',
        'version': _version,
      },
    );
    return _parseLogin(response);
  }

  Future<String> balance(QuzhiSession session) async {
    final response = await _request(
      'GET',
      'account/wallet',
      query: _common(session),
      session: session,
    );
    _requireSuccess(response, '余额获取失败');
    final data = _map(response['data']);
    final account = _asInt(data['accountMoney'] ?? data['accountRealMoney']);
    final given = _asInt(data['accountGivenMoney']);
    return ((account + given) / 1000).toStringAsFixed(2);
  }

  Future<List<QuzhiDevice>> scanNearby() async {
    final raw = await _channel.invokeListMethod<dynamic>('scanNearby');
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => QuzhiDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<QuzhiDevice> resolveDevice(
    QuzhiSession session,
    QuzhiDevice candidate,
  ) async {
    final lookup = candidate.address.isEmpty
        ? candidate.snCode
        : candidate.address;
    final response = await _request(
      'GET',
      'device/info/mac',
      query: {
        ..._common(session),
        'isNew': '1',
        'macAddress': lookup.startsWith('C0')
            ? '00${lookup.substring(2)}'
            : lookup,
      },
      session: session,
    );
    _requireSuccess(response, '设备信息查询失败');
    final data = _map(response['data']);
    return QuzhiDevice(
      snCode: data['snCode']?.toString().isNotEmpty == true
          ? data['snCode'].toString()
          : candidate.snCode,
      name: data['DevName']?.toString() ?? candidate.name,
      address: candidate.address,
      buildingName: data['LDName']?.toString() ?? '',
      floorName: data['LCName']?.toString() ?? '',
      roomName: data['FJName']?.toString() ?? '',
      projectName: data['PrjName']?.toString() ?? '',
      rssi: candidate.rssi,
    );
  }

  Future<QuzhiActiveOrder> start(
    QuzhiSession session,
    QuzhiDevice device,
  ) async {
    final command = await _postSession(
      session,
      'order/tcpDevice/downRate/rateOrder',
      {'snCode': device.snCode, 'xfModel': '0'},
    );
    final code = _asInt(command['errorCode'], fallback: -1);
    if (code == 307) {
      return _saveOrder(device.snCode, _ownedOrder(command['data']));
    }
    _requireSuccess(command, '启动热水失败');
    await Future<void>.delayed(const Duration(seconds: 5));
    final result = await _postSession(
      session,
      'order/tcpDevice/query/downRateResult',
      {'snCode': device.snCode, 'xfModel': '0'},
    );
    _requireSuccess(result, '启动结果未确认');
    final data = _map(result['data']);
    final state = _asInt(data['result'], fallback: -1);
    if (state == 2) throw const QuzhiException('余额不足');
    if (state != 0 && state != 36) throw const QuzhiException('启动结果未确认');
    return _saveOrder(device.snCode, _ownedOrder(data));
  }

  Future<String?> stop(QuzhiSession session, QuzhiActiveOrder order) async {
    final close = await _postSession(session, 'order/tcpDevice/closeOrder', {
      'snCode': order.snCode,
      'orderNo': order.orderNo,
    });
    final closeCode = _asInt(close['errorCode'], fallback: -1);
    if (closeCode != 0 && closeCode != 308) {
      throw QuzhiException(close['message']?.toString() ?? '结束热水失败');
    }
    if (closeCode == 308) {
      await _storage.delete(key: _orderKey);
      return null;
    }
    if (closeCode == 0) {
      await Future<void>.delayed(const Duration(seconds: 5));
      final confirmed = await _postSession(
        session,
        'order/tcpDevice/closeOrder/result/query',
        {'snCode': order.snCode, 'orderNo': order.orderNo},
      );
      final confirmedCode = _asInt(confirmed['errorCode'], fallback: -1);
      if (confirmedCode != 0 && confirmedCode != 308) {
        throw QuzhiException(confirmed['message']?.toString() ?? '结束结果未确认');
      }
    }
    // The water has already been confirmed off. Clear the local active order
    // before asking for the optional bill so a billing timeout cannot leave the
    // UI stuck in an active state.
    await _storage.delete(key: _orderKey);
    try {
      await Future<void>.delayed(const Duration(seconds: 5));
      final consume = await _postSession(
        session,
        'order/consumeOrder/result/query',
        {'orderNo': order.orderNo},
      );
      if (_asInt(consume['errorCode'], fallback: -1) != 0) return null;
      final data = _map(consume['data']);
      final before = _nullableInt(data['preDeductMoney']);
      final after = _nullableInt(data['preDeductMoneyAfter']);
      return before != null && after != null
          ? ((before - after) / 1000).toStringAsFixed(2)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<QuzhiActiveOrder> _saveOrder(String snCode, String orderNo) async {
    final order = QuzhiActiveOrder(
      orderNo: orderNo,
      snCode: snCode,
      startedAt: DateTime.now(),
    );
    await _storage.write(key: _orderKey, value: jsonEncode(order.toJson()));
    return order;
  }

  String _ownedOrder(dynamic raw) {
    final data = _map(raw);
    if (data['isOwner'] == false) throw const QuzhiException('设备正在被其他账号使用');
    final value = data['timeIds'] ?? data['orderNo'];
    if (value == null || value.toString().isEmpty) {
      throw const QuzhiException('服务器没有返回订单号');
    }
    return value.toString();
  }

  Future<Map<String, dynamic>> _postSession(
    QuzhiSession session,
    String path,
    Map<String, String> values,
  ) => _request(
    'POST',
    path,
    form: {..._common(session), ...values},
    session: session,
  );

  Map<String, String> _common(QuzhiSession session) => {
    'projectId': '${session.projectId}',
    'accountId': '${session.accountId}',
    'userId': '${session.userId}',
    'telephone': session.telephone,
    'telPhone': session.telephone,
    'loginCode': session.v3LoginCode.isEmpty
        ? session.loginCode
        : session.v3LoginCode,
    'phoneSystem': 'android',
    'version': _version,
  };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? form,
    QuzhiSession? session,
  }) async {
    final base = Uri.parse('$_base$path');
    final uri = query == null ? base : base.replace(queryParameters: query);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, quzhiUserAgent);
      if (session != null && session.projectId != 0) {
        request.headers.set('Config-Project', '${session.projectId}');
        request.headers.set(
          'Config-Keys',
          'module_list,advertise_type,question_list,service_phone_list,banner_list_app,activity_list_app,aliCard_popup_config',
        );
      }
      if (form != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(
          form.entries
              .map(
                (entry) =>
                    '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
              )
              .join('&'),
        );
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw QuzhiException('服务器请求失败：HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const QuzhiException('服务器响应格式异常');
      return Map<String, dynamic>.from(decoded);
    } on SocketException {
      throw const QuzhiException('无法连接趣智校园服务器');
    } on TimeoutException {
      throw const QuzhiException('连接趣智校园服务器超时');
    } finally {
      client.close(force: true);
    }
  }

  QuzhiSession _parseLogin(Map<String, dynamic> response) {
    final code = _asInt(response['errorCode'], fallback: -1);
    if (code != 0 && code != 2) {
      throw QuzhiException(response['message']?.toString() ?? '登录失败');
    }
    final root = _map(response['data']);
    final nestedAccount = _map(root['userAccount']);
    final account = nestedAccount.isEmpty ? root : nestedAccount;
    final loginCode = root['loginCode']?.toString() ?? '';
    return QuzhiSession(
      loginCode: loginCode,
      v3LoginCode: nestedAccount.isEmpty
          ? (root['v3LoginCode']?.toString().isNotEmpty == true
                ? root['v3LoginCode'].toString()
                : loginCode)
          : loginCode,
      telephone:
          (root['telephone'] ??
                  root['telPhone'] ??
                  account['telephone'] ??
                  account['telPhone'])
              ?.toString() ??
          '',
      userId: _asInt(root['userId'] ?? root['v3UserId'] ?? account['userId']),
      accountId: _asInt(account['accountId']),
      projectId: _asInt(account['projectId']),
      name: account['name']?.toString() ?? '',
    );
  }

  void _requireSuccess(Map<String, dynamic> response, String fallback) {
    if (_asInt(response['errorCode'], fallback: -1) != 0) {
      throw QuzhiException(response['message']?.toString() ?? fallback);
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static int _asInt(dynamic value, {int fallback = 0}) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;
  static int? _nullableInt(dynamic value) =>
      int.tryParse(value?.toString() ?? '');
}

class QuzhiException implements Exception {
  const QuzhiException(this.message);
  final String message;
  @override
  String toString() => message;
}
