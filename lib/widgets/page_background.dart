import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';

class PageBackground extends StatelessWidget {
  const PageBackground({
    super.key,
    required this.child,
    this.overlayColor = const Color(0xB8F7F7F7),
  });

  final Widget child;
  final Color overlayColor;

  static const _brighten = ColorFilter.matrix(<double>[
    1.18, 0, 0, 0, 22,
    0, 1.18, 0, 0, 22,
    0, 0, 1.18, 0, 22,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final wearer = context.watch<DrapeState>().profile.wearer;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * dpr).round().clamp(1, 4096);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const ColoredBox(color: AppColors.parchment),
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: _brighten,
            child: Image.asset(
              wearer.portraitAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              isAntiAlias: true,
              gaplessPlayback: true,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.parchment),
            ),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(color: overlayColor),
        ),
        SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 16),
          child: child,
        ),
      ],
    );
  }
}
