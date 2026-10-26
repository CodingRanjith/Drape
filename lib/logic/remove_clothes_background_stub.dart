import 'dart:typed_data';

/// Web / unsupported platforms: keep the original photo.
Future<Uint8List> removeClothesBackground(Uint8List bytes) async => bytes;

Future<void> warmUpClothesBackgroundModel() async {}
