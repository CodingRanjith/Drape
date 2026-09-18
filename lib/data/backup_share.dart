import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'excel_backup.dart';
import 'media_bytes.dart';
import 'share_backup.dart';
import 'stored_bytes.dart';

enum BackupFileKind { zip, excel, json }

String backupMime(BackupFileKind kind) => switch (kind) {
      BackupFileKind.zip => 'application/zip',
      BackupFileKind.excel => excelBackupMime,
      BackupFileKind.json => 'application/json',
    };

List<String> backupExtensions(BackupFileKind kind) => switch (kind) {
      BackupFileKind.zip => const ['zip'],
      BackupFileKind.excel => const ['xlsx'],
      BackupFileKind.json => const ['json'],
    };

Future<bool> saveBackupFile(
  Uint8List bytes,
  String fileName, {
  BackupFileKind kind = BackupFileKind.zip,
}) async {
  final mime = backupMime(kind);
  if (kIsWeb) {
    await shareBackupBytes(bytes, fileName, mimeType: mime);
    return true;
  }
  try {
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${kind.name}',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: backupExtensions(kind),
    );
    if (saved != null) return true;
  } catch (_) {}
  await shareBackupBytes(bytes, fileName, mimeType: mime);
  return true;
}

Future<Uint8List?> pickBackupFile({
  BackupFileKind kind = BackupFileKind.zip,
}) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: switch (kind) {
      BackupFileKind.zip => 'Pick backup zip',
      BackupFileKind.excel => 'Pick Excel sheet',
      BackupFileKind.json => 'Pick JSON backup',
    },
    type: FileType.custom,
    allowedExtensions: switch (kind) {
      BackupFileKind.zip => const ['zip'],
      BackupFileKind.excel => const ['xlsx', 'xls'],
      BackupFileKind.json => const ['json', 'zip'],
    },
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
  if (kind == BackupFileKind.excel) {
    if (name.endsWith('.xls') && !name.endsWith('.xlsx')) {
      throw const FormatException('Please save the sheet as .xlsx and try again.');
    }
    return bytes;
  }
  if (isZipBytes(bytes) ||
      name.endsWith('.zip') ||
      name.endsWith('.json') ||
      name.endsWith('.xlsx')) {
    return bytes;
  }
  throw const FormatException('Please pick a Drape backup file.');
}
