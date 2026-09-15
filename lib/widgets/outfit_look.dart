import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class OutfitLook extends StatelessWidget {
  const OutfitLook({
    super.key,
    required this.pieces,
    this.compact = false,
  });

  final List<Garment> pieces;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) {
      return Container(
        height: compact ? 110 : 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: const Text('No outfit yet'),
      );
    }

    final height = compact ? 132.0 : 268.0;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < pieces.length && i < 4; i++)
            Positioned(
              left: 12.0 + i * (compact ? 42 : 54),
              top: i.isEven ? 8 : 28,
              child: Transform.rotate(
                angle: (i - 1) * 0.05,
                child: Container(
                  width: compact ? 88 : 150,
                  height: compact ? 110 : 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: PhotoTile(garment: pieces[i], radius: 16, showName: !compact),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PieceRow extends StatelessWidget {
  const PieceRow({
    super.key,
    required this.garment,
    this.onSwap,
    this.onTap,
  });

  final Garment garment;
  final VoidCallback? onSwap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 52,
        height: 52,
        child: PhotoTile(garment: garment, radius: 14),
      ),
      title: Text(
        garment.name,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      subtitle: Text(garment.typeLabel),
      trailing: onSwap == null
          ? null
          : TextButton(onPressed: onSwap, child: const Text('Swap')),
    );
  }
}
