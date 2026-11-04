import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';

import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import 'garment_editor_screen.dart';

/// Wardrobe-style details popup (not a full-screen route).
Future<void> showGarmentDetailPopup(
  BuildContext context, {
  required String garmentId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => GarmentDetailPopup(garmentId: garmentId),
  );
}

class GarmentDetailPopup extends StatelessWidget {
  const GarmentDetailPopup({super.key, required this.garmentId});

  final String garmentId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final garment = state.garmentById(garmentId);
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width.clamp(280.0, 420.0);

    if (garment == null) {
      return Dialog(
        backgroundColor: const Color(0xFFF6EDE3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Text('Item not found'),
        ),
      );
    }

    final dialogH = size.height * 0.78;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: SizedBox(
        width: maxW,
        height: dialogH,
        child: Material(
          color: const Color(0xFFF6EDE3),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: Colors.black38,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          garment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: garment.favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: () => state.toggleFavorite(garment),
                      icon: Icon(
                        garment.favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: garment.favorite
                            ? AppColors.terracotta
                            : AppColors.ink,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GarmentEditorScreen(existing: garment),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Photo scales into leftover space — no scroll.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        var photoW = constraints.maxWidth;
                        var photoH = photoW * 4 / 3;
                        if (photoH > constraints.maxHeight) {
                          photoH = constraints.maxHeight;
                          photoW = photoH * 3 / 4;
                        }
                        return Center(
                          child: SizedBox(
                            width: photoW,
                            height: photoH,
                            child: PhotoTile(
                              garment: garment,
                              radius: 18,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${garment.typeLabel} · ${garment.formality.label} · ${garment.season.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      if (garment.cost != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Cost · ₹${garment.cost!.toStringAsFixed(garment.cost! % 1 == 0 ? 0 : 2)}',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: garment.primaryColor,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.ink, width: 1.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              colorNameOf(garment.primaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (garment.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          garment.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: Text(
                          'Delete from closet',
                          style:
                              GoogleFonts.manrope(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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
