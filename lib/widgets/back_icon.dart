import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../theme/app_theme.dart';

void goBack(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  goToShellTab?.call(0);
}

class AppBackIcon extends StatelessWidget {
  const AppBackIcon({super.key, this.color = AppColors.ink});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => goBack(context),
      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: color),
    );
  }
}
