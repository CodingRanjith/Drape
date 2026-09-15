import 'dart:typed_data';

import 'stored_bytes_stub.dart'
    if (dart.library.io) 'stored_bytes_io.dart'
    if (dart.library.html) 'stored_bytes_web.dart';

Future<Uint8List?> readStoredBytes(String? path) => readStoredBytesImpl(path);
