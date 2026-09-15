import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class ClothesPhotoRow extends StatelessWidget {
  const ClothesPhotoRow({
    super.key,
    required this.garments,
    this.selectedIds = const {},
    this.onTap,
    this.height = 132,
  });

  final List<Garment> garments;
  final Set<String> selectedIds;
  final void Function(Garment garment)? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (garments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: garments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final garment = garments[i];
          final selected = selectedIds.contains(garment.id);
          return GestureDetector(
            onTap: () {
              if (onTap != null) {
                onTap!(garment);
              } else {
                showPhotoZoom(context, garment);
              }
            },
            onDoubleTap: () => showPhotoZoom(context, garment),
            child: SizedBox(
              width: height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppColors.ink : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: PhotoTile(garment: garment, radius: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    garment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
