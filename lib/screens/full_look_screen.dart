import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class FullLookScreen extends StatelessWidget {
  const FullLookScreen({super.key});

  static const order = [
    GarmentCategory.dress,
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outerwear,
    GarmentCategory.shoes,
    GarmentCategory.accessory,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final outfit = state.todayPlan?.outfit;
    final pieces = <Garment>[];
    for (final category in order) {
      final item = state.garmentById(outfit?.idFor(category));
      if (item != null) pieces.add(item);
    }
    final tshirt = state.garmentById(outfit?.tshirtId);
    if (tshirt != null && pieces.every((g) => g.id != tshirt.id)) {
      pieces.insert(pieces.isEmpty ? 0 : 1, tshirt);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Today’s outfit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Wear this today',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
            const Text(
              'Here is every item you added for today.',
            ),
          const SizedBox(height: 20),
          if (pieces.isEmpty)
            const Text('This outfit is empty.')
          else
            ...pieces.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.typeLabel.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 12,
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: PhotoTile(garment: g, radius: 22, showName: true),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
