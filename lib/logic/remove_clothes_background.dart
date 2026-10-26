import 'dart:typed_data';

import 'remove_clothes_background_stub.dart'
    if (dart.library.io) 'remove_clothes_background_io.dart' as impl;

/// Removes the photo background for wardrobe items (transparent PNG when possible).
Future<Uint8List> removeClothesBackground(Uint8List bytes) =>
    impl.removeClothesBackground(bytes);

/// Optional Android model download so the first cutout is quicker.
Future<void> warmUpClothesBackgroundModel() =>
    impl.warmUpClothesBackgroundModel();
