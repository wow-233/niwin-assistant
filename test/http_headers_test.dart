import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_schedule/services/quzhi_service.dart';
import 'package:shiguang_schedule/services/webdav_service.dart';

void main() {
  test('custom HTTP headers contain ASCII only', () {
    for (final value in [quzhiUserAgent, webDavUserAgent]) {
      expect(value.codeUnits.every((unit) => unit <= 0x7f), isTrue);
    }
  });
}
