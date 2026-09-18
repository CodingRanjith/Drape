import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';

import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import 'garment_editor_screen.dart';

class GarmentDetailScreen extends StatelessWidget {
  const GarmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final garment = state.garmentById(id);
    if (garment == null) {
      return const Scaffold(body: Center(child: Text('Item not found')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackIcon(),
        title: Text(garment.name),
        actions: [
          IconButton(
            tooltip: garment.favorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => state.toggleFavorite(garment),
            icon: Icon(
              garment.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: garment.favorite ? AppColors.terracotta : AppColors.ink,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GarmentEditorScreen(existing: garment)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: PhotoTile(garment: garment, radius: 28),
          ),
          const SizedBox(height: 20),
          Text(garment.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '${garment.typeLabel} · ${garment.formality.label} · ${garment.season.label}',
          ),
          if (garment.cost != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cost · ₹${garment.cost!.toStringAsFixed(garment.cost! % 1 == 0 ? 0 : 2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: garment.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                colorNameOf(garment.primaryColor),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Stat(
            label: 'Times worn',
            value: '${garment.wearCount}',
          ),
          _Stat(
            label: 'Last worn',
            value: garment.lastWornAt == null
                ? 'Not worn yet'
                : DateFormat('d MMM y').format(garment.lastWornAt!),
          ),
          if (garment.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(garment.notes),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => state.toggleLaundry(garment),
            icon: Icon(
              garment.inLaundry ? Icons.checkroom_outlined : Icons.local_laundry_service_outlined,
            ),
            label: Text(garment.inLaundry ? 'Mark as clean' : 'Mark as laundry'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete this item?'),
                  content: const Text(
                    'It will be removed from your closet and from any outfits that use it.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await state.deleteGarment(garment.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete from closet'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
