import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_nav.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import 'garment_photo.dart';

Future<Uint8List?> pickProfileImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) return null;
  final shot = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1200,
    imageQuality: 88,
  );
  if (shot == null) return null;
  return shot.readAsBytes();
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.radius = 18,
    this.onTap,
    this.imageBytes,
    this.photoPath,
    this.wearer,
    this.showEditBadge = false,
    this.borderColor,
    this.fallbackColor = AppColors.clay,
  });

  final double radius;
  final VoidCallback? onTap;
  final Uint8List? imageBytes;
  final String? photoPath;
  final Wearer? wearer;
  final bool showEditBadge;
  final Color? borderColor;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<MineState>().profile;
    final path = photoPath ?? profile.photoPath;
    final photo = imageBytes != null
        ? MemoryImage(imageBytes!)
        : garmentImageProvider(path) ??
              AssetImage((wearer ?? profile.wearer).portraitAsset);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: fallbackColor,
      backgroundImage: photo,
    );

    Widget child = avatar;
    if (borderColor != null) {
      child = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: avatar,
      );
    }
    if (showEditBadge) {
      final badge = radius * 0.72;
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: badge * 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Tooltip(
      message: 'Profile',
      child: GestureDetector(
        onTap: onTap ?? () => goToShellTab?.call(4),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}
