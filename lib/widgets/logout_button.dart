import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/drape_state.dart';

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text(
        'You will go back to Women or Men selection. Your clothes stay on this phone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<DrapeState>().logoutToWearerChoice();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Logout',
      onPressed: () => confirmLogout(context),
      icon: const Icon(Icons.logout_rounded, size: 26),
    );
  }
}
