import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class BackupService {
  const BackupService._();

  static Future<bool> exportJson(String json) async {
    final now = DateTime.now();
    final name =
        'niwin-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出泥win助手备份',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    return path != null;
  }

  static Future<String?> importJson() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择泥win助手备份',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    return bytes == null ? null : utf8.decode(bytes);
  }
}
