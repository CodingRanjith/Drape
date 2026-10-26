import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../logic/remove_clothes_background.dart';
import '../models/wardrobe.dart';
import '../screens/in_app_camera_screen.dart';
import 'scanner_shape_guide.dart';

/// Opens the in-app camera screen (never the system camera app).
Future<Uint8List?> openInAppCamera(
  BuildContext context, {
  int maxWidth = 1600,
  int imageQuality = 92,
  WardrobeCategory? wardrobeCategory,
  GarmentCategory? garmentCategory,
  String? guideLabel,
  ScannerShape? shape,
  bool removeBackground = true,
}) async {
  final resolvedShape = shape ??
      (wardrobeCategory != null
          ? scannerShapeForCategory(wardrobeCategory)
          : garmentCategory != null
              ? scannerShapeForGarment(garmentCategory)
              : ScannerShape.generic);
  final label =
      guideLabel ?? wardrobeCategory?.label ?? garmentCategory?.label;

  final bytes = await Navigator.of(context, rootNavigator: true).push<Uint8List>(
    PageRouteBuilder<Uint8List>(
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (_, _, _) => InAppCameraScreen(
        shape: resolvedShape,
        guideLabel: label,
      ),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  if (bytes == null) return null;
  return _finish(
    bytes,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
    removeBackground: removeBackground,
  );
}

/// Picks an image as bytes.
/// Camera → in-app camera only. Gallery → system photo picker.
/// Clothes photos get on-device background removal by default.
Future<Uint8List?> pickAppImage(
  BuildContext context, {
  required ImageSource source,
  int maxWidth = 1600,
  int imageQuality = 92,
  WardrobeCategory? wardrobeCategory,
  GarmentCategory? garmentCategory,
  String? guideLabel,
  ScannerShape? shape,
  bool removeBackground = true,
}) async {
  if (source == ImageSource.camera) {
    return openInAppCamera(
      context,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
      wardrobeCategory: wardrobeCategory,
      garmentCategory: garmentCategory,
      guideLabel: guideLabel,
      shape: shape,
      removeBackground: removeBackground,
    );
  }

  final shot = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth.toDouble(),
    imageQuality: imageQuality,
  );
  if (shot == null) return null;
  final bytes = await shot.readAsBytes();
  return _finish(
    bytes,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
    removeBackground: removeBackground,
  );
}

Future<Uint8List> _finish(
  Uint8List bytes, {
  required int maxWidth,
  required int imageQuality,
  required bool removeBackground,
}) async {
  final shrunk = _shrink(bytes, maxWidth: maxWidth, quality: imageQuality);
  if (!removeBackground) return shrunk;
  return removeClothesBackground(shrunk);
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
    // Keep PNG when input already has alpha; otherwise JPEG for the cutout step.
    if (decoded.numChannels >= 4) {
      return Uint8List.fromList(img.encodePng(resized));
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (_) {
    return bytes;
  }
}
