import 'dart:typed_data';

import 'media_bytes.dart';

Future<Uint8List?> readStoredBytesImpl(String? path) async =>
    bytesFromDataUri(path);
