import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../screens/in_app_camera_screen.dart';

/// Picks an image as bytes.
/// Camera opens an in-app preview (does not launch the system camera app).
/// Gallery still uses the system photo picker.
Future<Uint8List?> pickAppImage(
  BuildContext context, {
  required ImageSource source,
  int maxWidth = 1600,
  int imageQuality = 92,
}) async {
  if (source == ImageSource.camera) {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InAppCameraScreen(),
      ),
    );
    if (bytes == null) return null;
    return _shrink(bytes, maxWidth: maxWidth, quality: imageQuality);
  }

  final shot = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth.toDouble(),
    imageQuality: imageQuality,
  );
  if (shot == null) return null;
  return shot.readAsBytes();
}

Uint8List _shrink(
  Uint8List bytes, {
  required int maxWidth,
  required int quality,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > maxWidth
        ? img.copyResize(
            decoded,
            width: maxWidth,
            interpolation: img.Interpolation.linear,
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (_) {
    return bytes;
  }
}
