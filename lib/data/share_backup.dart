import 'dart:typed_data';

import 'backup_share_stub.dart'
    if (dart.library.io) 'backup_share_io.dart'
    if (dart.library.html) 'backup_share_web.dart';

export 'backup_share_stub.dart'
    if (dart.library.io) 'backup_share_io.dart'
    if (dart.library.html) 'backup_share_web.dart';

Future<void> shareBackupBytes(
  Uint8List zip,
  String fileName, {
  String mimeType = 'application/zip',
}) =>
    shareBackupBytesImpl(zip, fileName, mimeType: mimeType);
