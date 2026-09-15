import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/closet_add.dart';
import '../widgets/common.dart';
import '../widgets/settings_button.dart';
import 'garment_detail_screen.dart';
import 'garment_editor_screen.dart';

class CollectionSetsScreen extends StatelessWidget {
  const CollectionSetsScreen({super.key, required this.collection});

  final StyleCollection collection;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final sets = state.setsFor(collection);

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.label),
        actions: const [SettingsButton()],
      ),
      floatingActionButton: collection.comingSoon || sets.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => state.addClothSet(collection),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
      body: collection.comingSoon
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Lottie.asset(
                    'assets/coming_soon.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            )
          : sets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                child: EmptyState(
                  title: 'Add a set',
                  body:
                      'Nothing here yet. Tap Add set, then add each piece with a photo.',
                  actionLabel: 'Add set',
                  onAction: () => state.addClothSet(collection),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                Text(
                  collection.subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only sets you add are shown. Add pieces inside a set, or delete a set you do not need.',
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < sets.length; i++)
                  _SetCard(
                    set: sets[i],
                    number: i + 1,
                    pieces: state.piecesOf(sets[i].outfit),
                    onAddPiece: (type) => _addPiece(context, sets[i], type),
                    onRename: () => _rename(context, sets[i]),
                    onDelete: () => _deleteSet(context, sets[i]),
                    onRemovePiece: (garment) => state.assignToClothSet(
                      sets[i].id,
                      garment.category,
                      null,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _addPiece(
    BuildContext context,
    ClothSet set,
    ClothesType type,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentEditorScreen(
          initialCategory: type.category,
          initialTopKind: type.topKind,
          assignToSetId: set.id,
          pairWithId: type.category == GarmentCategory.bottom
              ? set.outfit.topId
              : null,
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, ClothSet set) async {
    final name = TextEditingController(text: set.name);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename set'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Set name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    if (next == null || !context.mounted) return;
    await context.read<DrapeState>().renameClothSet(set.id, next);
  }

  Future<void> _deleteSet(BuildContext context, ClothSet set) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this set?'),
        content: const Text('The set will be removed. Clothes stay in your closet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<DrapeState>().deleteClothSet(set.id);
    }
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.set,
    required this.number,
    required this.pieces,
    required this.onAddPiece,
    required this.onRename,
    required this.onDelete,
    required this.onRemovePiece,
  });

  final ClothSet set;
  final int number;
  final List<Garment> pieces;
  final void Function(ClothesType type) onAddPiece;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(Garment garment) onRemovePiece;

  static const _order = [
    GarmentCategory.dress,
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outerwear,
    GarmentCategory.shoes,
    GarmentCategory.accessory,
  ];

  @override
  Widget build(BuildContext context) {
    final ordered = <Garment>[];
    for (final category in _order) {
      for (final g in pieces) {
        if (g.category == category) ordered.add(g);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onRename,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set.name.isEmpty ? 'Set $number' : set.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.ink,
                          ),
                        ),
                        const Text(
                          'Tap name to rename',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.terracotta,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => pickClothesType(context, onPick: onAddPiece),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                IconButton(
                  tooltip: 'Delete set',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ordered.isEmpty)
              const Text(
                'Nothing in this set yet. Tap Add.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ordered.map((g) {
                  return SizedBox(
                    width: 86,
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GarmentDetailScreen(id: g.id),
                                    ),
                                  ),
                                  child: PhotoTile(garment: g, radius: 14),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => onRemovePiece(g),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.close, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          g.typeLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
