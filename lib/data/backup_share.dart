import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'media_bytes.dart';
import 'share_backup.dart';
import 'stored_bytes.dart';

Future<bool> saveBackupFile(Uint8List zip, String fileName) async {
  if (kIsWeb) {
    await shareBackupBytes(zip, fileName);
    return true;
  }
  final saved = await FilePicker.platform.saveFile(
    dialogTitle: 'Save backup zip',
    fileName: fileName,
    bytes: zip,
    type: FileType.custom,
    allowedExtensions: const ['zip'],
  );
  if (saved != null) return true;
  await shareBackupBytes(zip, fileName);
  return true;
}

Future<Uint8List?> pickBackupFile() async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Pick backup zip',
    type: FileType.any,
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  var bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    bytes = await readStoredBytes(file.path);
  }
  if (bytes == null || bytes.isEmpty) {
    throw const FormatException('Could not read that file.');
  }
  final name = file.name.toLowerCase();
  if (isZipBytes(bytes) || name.endsWith('.zip') || name.endsWith('.json')) {
    return bytes;
  }
  throw const FormatException('Please pick the backup .zip file.');
}
