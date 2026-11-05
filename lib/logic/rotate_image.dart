import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Rotates wardrobe photo bytes by [degrees] (90 / -90 / 180).
/// Keeps PNG when the source has alpha (cutouts); otherwise JPEG.
Uint8List rotateImageBytes(Uint8List bytes, {int degrees = 90}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final turned = img.copyRotate(decoded, angle: degrees);
    if (decoded.numChannels >= 4 || _looksPng(bytes)) {
      return Uint8List.fromList(img.encodePng(turned));
    }
    return Uint8List.fromList(img.encodeJpg(turned, quality: 92));
  } catch (_) {
    return bytes;
  }
}

bool _looksPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
