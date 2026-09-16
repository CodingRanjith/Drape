import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../screens/settings_screen.dart';
import 'profile_avatar.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ProfileAvatar(
          onTap: () {
            if (goToShellTab != null) {
              Navigator.of(context).popUntil((route) => route.isFirst);
              goToShellTab!(4);
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ),
    );
  }
}
