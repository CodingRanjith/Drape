import 'dart:io';

import 'package:flutter/material.dart';

ImageProvider? fileImageProvider(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return FileImage(file);
}
