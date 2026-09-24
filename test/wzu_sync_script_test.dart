import 'package:flutter_test/flutter_test.dart';
import 'package:shiguang_schedule/services/wzu_sync_script.dart';

void main() {
  test('Zhengfang request asks for complete timetable fields', () {
    expect(wzuAssistantScript, contains("params.set('kzlx', 'ck')"));
    expect(
      wzuAssistantScript,
      contains("'X-Requested-With': 'XMLHttpRequest'"),
    );
    expect(wzuAssistantScript, contains("method: 'zhengfang-api+dom'"));
    expect(
      wzuAssistantScript,
      contains("item.location || (hint && hint.location)"),
    );
  });
}
