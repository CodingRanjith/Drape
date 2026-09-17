import 'dart:typed_data';

import 'persist_image_stub.dart'
    if (dart.library.io) 'persist_image_io.dart'
    if (dart.library.html) 'persist_image_web.dart';

bool _isPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

Future<String> persistImage(Uint8List bytes, String id) {
  if (_isPng(bytes)) {
    return persistBytesImpl(bytes, '$id.png', 'image/png');
  }
  return persistBytesImpl(bytes, '$id.jpg', 'image/jpeg');
}

Future<String> persistAudio(
  Uint8List bytes,
  String id, {
  String ext = 'mp3',
  String mime = 'audio/mpeg',
}) => persistBytesImpl(bytes, '$id.$ext', mime);

Future<void> clearPersistedMedia() => clearPersistedMediaImpl();
