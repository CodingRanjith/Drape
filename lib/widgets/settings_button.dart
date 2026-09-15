import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
      icon: const Icon(Icons.settings_outlined, size: 26),
    );
  }
}
