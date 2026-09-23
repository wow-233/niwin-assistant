import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ImportedFont {
  const ImportedFont({
    required this.path,
    required this.family,
    required this.displayName,
  });

  final String path;
  final String family;
  final String displayName;
}

class CustomFontService {
  static Future<bool> load(String path, String family) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    return true;
  }

  static Future<ImportedFont?> pickAndLoad() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) return null;

    final directory = await getApplicationSupportDirectory();
    final fontDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}fonts',
    );
    await fontDirectory.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path =
        '${fontDirectory.path}${Platform.pathSeparator}user-$stamp.ttf';
    await File(path).writeAsBytes(bytes, flush: true);
    final family = 'UserFont$stamp';
    await load(path, family);
    final displayName = picked.name.replaceFirst(
      RegExp(r'\.ttf$', caseSensitive: false),
      '',
    );
    return ImportedFont(path: path, family: family, displayName: displayName);
  }
}
