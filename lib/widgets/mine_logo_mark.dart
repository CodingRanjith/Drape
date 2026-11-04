import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared Mine brand mark (`assets/brand/app_icon.png`).
class MineLogoMark extends StatelessWidget {
  const MineLogoMark({
    super.key,
    this.size = 44,
    this.radius = 14,
    this.shadow = true,
  });

  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/brand/app_icon.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.terracotta,
          child: Icon(Icons.checkroom_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
