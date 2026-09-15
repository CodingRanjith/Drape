import 'dart:convert';
import 'dart:typed_data';

Future<String> persistBytesImpl(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
