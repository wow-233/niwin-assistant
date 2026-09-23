import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundService {
  static Future<String?> pickAndCopy() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) return null;
    final directory = await getApplicationSupportDirectory();
    final folder = Directory(
      '${directory.path}${Platform.pathSeparator}backgrounds',
    );
    await folder.create(recursive: true);
    final extension = picked.extension?.toLowerCase() ?? 'jpg';
    final path =
        '${folder.path}${Platform.pathSeparator}schedule-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
