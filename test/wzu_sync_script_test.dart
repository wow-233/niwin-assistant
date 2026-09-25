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
    expect(wzuAssistantScript, contains("p[1]=location"));
    expect(
      wzuAssistantScript,
      contains("paragraphField(node, ['上课地点', '地点', '教室', '场地'], 1)"),
    );
    expect(wzuAssistantScript, isNot(contains("querySelectorAll(':scope > p")));
    expect(wzuAssistantScript, contains('})().catch(error =>'));
    expect(
      wzuAssistantScript,
      contains("document.querySelector('#kbgrid_table_0')"),
    );
    expect(
      wzuAssistantScript,
      contains("cell.querySelectorAll('.timetable_con')"),
    );
    expect(
      wzuAssistantScript,
      contains("confidence: 'zhengfang-general-grid'"),
    );
    expect(
      wzuAssistantScript,
      contains("document.querySelector('#kblist_table')"),
    );
  });
}
