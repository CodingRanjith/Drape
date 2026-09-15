import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import 'garment_photo.dart';

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.garment,
    this.radius = 18,
    this.showName = false,
  });

  final Garment garment;
  final double radius;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final photo = garmentImageProvider(garment.imagePath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image(image: photo, fit: BoxFit.cover)
          else
            ColoredBox(
              color: garment.primaryColor,
              child: Icon(
                garment.category.icon,
                color: _onColor(garment.primaryColor),
                size: 36,
              ),
            ),
          if (showName)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  garment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (garment.inLaundry)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: Text(
                  'In laundry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _onColor(Color color) {
    return color.computeLuminance() > 0.55 ? AppColors.ink : Colors.white;
  }
}

void showPhotoZoom(BuildContext context, Garment garment) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) => _PhotoZoomPage(garment: garment),
    ),
  );
}

class _PhotoZoomPage extends StatelessWidget {
  const _PhotoZoomPage({required this.garment});

  final Garment garment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: PhotoTile(garment: garment, radius: 0, showName: false),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Text(
                  garment.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.checkroom_outlined,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.terracottaSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.terracotta, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        ?trailing,
      ],
    );
  }
}
