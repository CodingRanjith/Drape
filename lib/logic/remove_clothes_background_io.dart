import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:native_cutout/native_cutout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device background removal for clothes photos.
/// Returns a transparent PNG when successful; otherwise the original bytes.
Future<Uint8List> removeClothesBackground(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  if (!(Platform.isAndroid || Platform.isIOS)) return bytes;
  if (bytes.isEmpty) return bytes;

  File? temp;
  try {
    final dir = await getTemporaryDirectory();
    final ext = _looksPng(bytes) ? 'png' : 'jpg';
    temp = File(
      p.join(
        dir.path,
        'mine_cutout_${DateTime.now().microsecondsSinceEpoch}.$ext',
      ),
    );
    await temp.writeAsBytes(bytes, flush: true);

    if (Platform.isAndroid) {
      final ready = await NativeCutout.isModelAvailable();
      if (!ready) {
        final downloaded = await NativeCutout.downloadModel();
        if (!downloaded) return bytes;
      }
    }

    final result = await NativeCutout.removeBackground(
      temp.path,
      options: const CutoutOptions(
        cropToSubject: true,
        writeToCache: false,
      ),
    );

    switch (result) {
      case CutoutBytesSuccess(:final pngBytes):
        return pngBytes.isNotEmpty ? pngBytes : bytes;
      case CutoutFileSuccess(:final path):
        return await File(path).readAsBytes();
      case CutoutFailure(:final code, :final message):
        debugPrint('BG remove skipped: ${code.name} — $message');
        return bytes;
    }
  } catch (e) {
    debugPrint('BG remove failed: $e');
    return bytes;
  } finally {
    try {
      if (temp != null && await temp.exists()) await temp.delete();
    } catch (_) {}
  }
}

/// Prefetch Android ML Kit model so the first clothes upload is faster.
Future<void> warmUpClothesBackgroundModel() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final ready = await NativeCutout.isModelAvailable();
    if (!ready) await NativeCutout.downloadModel();
  } catch (e) {
    debugPrint('BG model warm-up skipped: $e');
  }
}

bool _looksPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
