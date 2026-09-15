import 'dart:typed_data';

import 'persist_image_stub.dart'
    if (dart.library.io) 'persist_image_io.dart'
    if (dart.library.html) 'persist_image_web.dart';

Future<String> persistImage(Uint8List bytes, String id) =>
    persistBytesImpl(bytes, '$id.jpg', 'image/jpeg');

Future<String> persistAudio(
  Uint8List bytes,
  String id, {
  String ext = 'mp3',
  String mime = 'audio/mpeg',
}) => persistBytesImpl(bytes, '$id.$ext', mime);
