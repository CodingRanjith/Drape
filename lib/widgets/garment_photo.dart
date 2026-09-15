import 'dart:convert';

import 'package:flutter/material.dart';

import 'garment_photo_io.dart' if (dart.library.html) 'garment_photo_web.dart';

ImageProvider? garmentImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) {
    final comma = path.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(path.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  if (path.startsWith('http') || path.startsWith('blob:')) {
    return NetworkImage(path);
  }
  return fileImageProvider(path);
}
