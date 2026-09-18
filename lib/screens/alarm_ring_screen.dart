import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/garment_photo.dart';

class AlarmRingScreen extends StatelessWidget {
  const AlarmRingScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final event = state.eventById(eventId) ?? state.ringingEvent;
    if (event == null) {
      return const Scaffold(body: Center(child: Text('Alarm finished')));
    }
    final look = state.partyLookById(event.partyLookId);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Text(
                  event.kind.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  DateFormat('h:mm a').format(event.at),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, d MMMM').format(event.at),
                  style: const TextStyle(color: Color(0xFFD9C7B8)),
                ),
                const Spacer(),
                Builder(
                  builder: (context) {
                    final clothes = event.garmentIds
                        .map(state.garmentById)
                        .whereType<Garment>()
                        .toList();
                    if (clothes.isNotEmpty) {
                      return ClothesPhotoRow(garments: clothes, height: 120);
                    }
                    if (look?.imagePath != null &&
                        garmentImageProvider(look!.imagePath) != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 180,
                          width: 140,
                          child: Image(
                            image: garmentImageProvider(look.imagePath)!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await state.stopRinging();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Stop alarm'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await state.snoozeRinging();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Snooze 5 minutes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
