import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> persistBytesImpl(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  final root = await getApplicationDocumentsDirectory();
  final folder = mime.startsWith('audio') ? 'music' : 'garments';
  final dir = Directory(p.join(root.path, folder));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final dest = File(p.join(dir.path, filename));
  await dest.writeAsBytes(bytes, flush: true);
  return dest.path;
}

Future<void> clearPersistedMediaImpl() async {
  final root = await getApplicationDocumentsDirectory();
  for (final folder in const ['garments', 'music']) {
    final dir = Directory(p.join(root.path, folder));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
