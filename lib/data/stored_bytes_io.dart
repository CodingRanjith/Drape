import 'dart:io';
import 'dart:typed_data';

import 'media_bytes.dart';

Future<Uint8List?> readStoredBytesImpl(String? path) async {
  final fromUri = bytesFromDataUri(path);
  if (fromUri != null) return fromUri;
  if (path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}
