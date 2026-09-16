import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../theme/app_theme.dart';

const kBackArrowAsset = 'assets/brand/back-arrow.png';

void goBack(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  goToShellTab?.call(0);
}

class BackArrowGlyph extends StatelessWidget {
  const BackArrowGlyph({
    super.key,
    this.size = 22,
    this.color = AppColors.terracotta,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        kBackArrowAsset,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Icon(
          Icons.arrow_back_rounded,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

class AppBackIcon extends StatelessWidget {
  const AppBackIcon({super.key, this.color = AppColors.terracotta});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => goBack(context),
      icon: BackArrowGlyph(color: color),
    );
  }
}
