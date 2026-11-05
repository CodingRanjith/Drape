import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:native_cutout/native_cutout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

var _onnxReady = false;
Future<void>? _onnxInit;

/// On-device background removal for clothes photos.
/// Prefers the ONNX clothes/subject model; falls back to native cutout on
/// Android/iOS when ONNX is unavailable. Returns a transparent PNG when
/// successful; otherwise the original bytes.
Future<Uint8List> removeClothesBackground(Uint8List bytes) async {
  if (bytes.isEmpty) return bytes;

  final onnx = await _removeWithOnnx(bytes);
  if (onnx != null && onnx.isNotEmpty) return onnx;

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final native = await _removeWithNativeCutout(bytes);
    if (native != null && native.isNotEmpty) return native;
  }

  return bytes;
}

/// Prefetch ONNX session (+ Android ML Kit model) so the first upload is faster.
Future<void> warmUpClothesBackgroundModel() async {
  await _ensureOnnx();
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final ready = await NativeCutout.isModelAvailable();
    if (!ready) await NativeCutout.downloadModel();
  } catch (e) {
    debugPrint('Native BG model warm-up skipped: $e');
  }
}

Future<void> _ensureOnnx() {
  return _onnxInit ??= () async {
    try {
      await BackgroundRemover.instance.initializeOrt();
      _onnxReady = true;
    } catch (e) {
      _onnxReady = false;
      _onnxInit = null;
      debugPrint('ONNX BG init failed: $e');
    }
  }();
}

Future<Uint8List?> _removeWithOnnx(Uint8List bytes) async {
  try {
    await _ensureOnnx();
    if (!_onnxReady) return null;

    final image = await BackgroundRemover.instance.removeBg(
      bytes,
      threshold: 0.45,
      smoothMask: true,
      enhanceEdges: true,
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    final out = png.buffer.asUint8List();
    return out.isNotEmpty ? out : null;
  } catch (e) {
    debugPrint('ONNX BG remove failed: $e');
    return null;
  }
}

Future<Uint8List?> _removeWithNativeCutout(Uint8List bytes) async {
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
        if (!downloaded) return null;
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
        return pngBytes.isNotEmpty ? pngBytes : null;
      case CutoutFileSuccess(:final path):
        final fileBytes = await File(path).readAsBytes();
        return fileBytes.isNotEmpty ? fileBytes : null;
      case CutoutFailure(:final code, :final message):
        debugPrint('Native BG remove skipped: ${code.name} — $message');
        return null;
    }
  } catch (e) {
    debugPrint('Native BG remove failed: $e');
    return null;
  } finally {
    try {
      if (temp != null && await temp.exists()) await temp.delete();
    } catch (_) {}
  }
}

bool _looksPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
