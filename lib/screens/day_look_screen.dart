import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/outfit_look.dart';
import 'garment_detail_screen.dart';

class DayLookScreen extends StatelessWidget {
  const DayLookScreen({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final day = state.week?.forDate(date);
    if (day == null) {
      return const Scaffold(body: Center(child: Text('Day not found')));
    }
    final pieces = state.piecesOf(day.outfit);
    final categories = <GarmentCategory>[];
    for (final type in ClothesType.forWearer(state.profile.wearer)) {
      if (!categories.contains(type.category)) categories.add(type.category);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackIcon(),
        title: Text(DateFormat('EEEE d MMM').format(day.date)),
        actions: [
          IconButton(
            tooltip: day.locked ? 'Allow change' : 'Keep this outfit',
            onPressed: () => state.toggleLock(day),
            icon: Icon(day.locked ? Icons.lock_rounded : Icons.lock_open_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          OutfitLook(pieces: pieces),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: day.outfit == null
                      ? null
                      : () => day.worn ? state.undoWorn(day) : state.markWorn(day),
                  child: Text(day.worn ? 'Undo' : 'I wore this'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: day.locked ? null : () => state.shuffleDay(day),
                  child: const Text('Show another'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader('Change items'),
          const SizedBox(height: 8),
          const Text('Tap an item to pick another one from your closet.'),
          const SizedBox(height: 12),
          for (final category in categories)
            _Slot(
              day: day,
              category: category,
              garment: state.garmentById(day.outfit?.idFor(category)),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.day,
    required this.category,
    required this.garment,
  });

  final DayPlan day;
  final GarmentCategory category;
  final Garment? garment;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _pick(context, state),
        leading: SizedBox(
          width: 52,
          height: 52,
          child: garment == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.terracottaSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(category.icon, color: AppColors.terracotta),
                )
              : PhotoTile(garment: garment!, radius: 14),
        ),
        title: Text(
          garment?.name ??
              'Add ${ClothesType.slotLabel(category, state.profile.wearer).toLowerCase()}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        subtitle: Text(garment?.typeLabel ?? ClothesType.slotLabel(category, state.profile.wearer)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (garment != null && !day.locked)
              IconButton(
                tooltip: 'Change',
                onPressed: () => state.swapPiece(day, category),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, DrapeState state) async {
    final options = state.garments
        .where((g) => g.category == category && !g.inLaundry)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.parchment,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ClothesType.slotLabel(category, state.profile.wearer),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (options.isEmpty)
                const Text('Nothing here yet. Add this type in Closet.')
              else
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        title: const Text('Remove this item'),
                        leading: const Icon(Icons.hide_source_outlined),
                        onTap: () {
                          state.assignPiece(day, category, null);
                          Navigator.pop(context);
                        },
                      ),
                      ...options.map(
                        (g) => ListTile(
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: PhotoTile(garment: g, radius: 12),
                          ),
                          title: Text(g.name),
                          subtitle: Text(g.formality.label),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new_rounded),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GarmentDetailScreen(id: g.id),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            state.assignPiece(day, category, g.id);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
