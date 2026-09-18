import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/create_set_sheet.dart';
import '../widgets/page_background.dart';
import 'garment_editor_screen.dart';

class CollectionSetsScreen extends StatelessWidget {
  const CollectionSetsScreen({super.key, required this.collection});

  final StyleCollection collection;

  Future<void> _createSet(BuildContext context) async {
    await showCreateSetSheet(context, collection: collection);
  }

  Future<void> _openSet(BuildContext context, ClothSet set) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SetDetailsPopup(setId: set.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final sets = state.setsFor(collection);

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: Text(collection.label),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createSet(context),
          child: const Icon(Icons.add_rounded),
        ),
        body: sets.isEmpty
            ? _EmptySets(onAdd: () => _createSet(context))
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
                  const SizedBox(height: 6),
                  Text(
                    '${sets.length} ${sets.length == 1 ? 'set' : 'sets'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < sets.length; i++)
                    _SetCard(
                      set: sets[i],
                      number: i + 1,
                      pieces: state.piecesOf(sets[i].outfit),
                      onTap: () => _openSet(context, sets[i]),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptySets extends StatelessWidget {
  const _EmptySets({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.layers_outlined,
              size: 56,
              color: AppColors.clay,
            ),
            const SizedBox(height: 16),
            Text(
              'No sets yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a set with topwear, bottomwear, and other wardrobe pieces. Tap a set later to edit details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.set,
    required this.number,
    required this.pieces,
    required this.onTap,
  });

  final ClothSet set;
  final int number;
  final List<Garment> pieces;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shelves = <String>{
      for (final g in pieces) g.shelfLabel,
    }.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: pieces.isEmpty
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.terracottaSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.layers_outlined,
                              color: AppColors.terracotta,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: PhotoTile(garment: pieces.first, radius: 0),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set.name.trim().isEmpty ? 'Set $number' : set.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pieces.isEmpty
                              ? 'Empty set · tap to add pieces'
                              : '${pieces.length} pieces · ${shelves.take(3).join(' · ')}'
                                  '${shelves.length > 3 ? '…' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (pieces.length > 1) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: pieces.length.clamp(0, 5),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                return SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: PhotoTile(
                                    garment: pieces[index],
                                    radius: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetDetailsPopup extends StatelessWidget {
  const _SetDetailsPopup({required this.setId});

  final String setId;

  Future<void> _edit(BuildContext context, ClothSet set) async {
    Navigator.pop(context);
    await showCreateSetSheet(
      context,
      collection: set.collection,
      existing: set,
    );
  }

  Future<void> _uploadPiece(BuildContext context, ClothSet set) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentEditorScreen(assignToSetId: set.id),
      ),
    );
  }

  Future<void> _addFromWardrobe(BuildContext context, ClothSet set) async {
    final state = context.read<DrapeState>();
    final shelves = state.populatedShelves();
    if (shelves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add clothes in My Wardrobe first.'),
        ),
      );
      return;
    }
    final pickedShelf = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Add wardrobe category',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              for (final shelf in shelves)
                ListTile(
                  title: Text(shelf.label),
                  subtitle: Text('${shelf.items.length} items'),
                  onTap: () => Navigator.pop(context, shelf.label),
                ),
            ],
          ),
        );
      },
    );
    if (pickedShelf == null || !context.mounted) return;
    final items = shelves.firstWhere((s) => s.label == pickedShelf).items;
    final garment = await showModalBottomSheet<Garment>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Pick from $pickedShelf',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final g = items[index];
                      return InkWell(
                        onTap: () => Navigator.pop(context, g),
                        borderRadius: BorderRadius.circular(14),
                        child: PhotoTile(garment: g, radius: 14),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (garment == null || !context.mounted) return;
    await state.assignToClothSet(set.id, garment.category, garment.id);
  }

  Future<void> _delete(BuildContext context, ClothSet set) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this set?'),
        content: const Text(
          'The set will be removed. Clothes stay in your closet.',
        ),
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
    if (ok != true || !context.mounted) return;
    await context.read<DrapeState>().deleteClothSet(set.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final set = state.clothSetById(setId);
    if (set == null) {
      return const SizedBox.shrink();
    }
    final pieces = state.piecesOf(set.outfit);
    final byShelf = <String, List<Garment>>{};
    for (final g in pieces) {
      byShelf.putIfAbsent(g.shelfLabel, () => []).add(g);
    }

    return Dialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      set.name.trim().isEmpty ? 'Set details' : set.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                set.collection.label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: pieces.isEmpty
                    ? const Center(
                        child: Text(
                          'No pieces yet. Add from wardrobe or upload a new item.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final entry in byShelf.entries) ...[
                            Text(
                              entry.key,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: AppColors.terracotta,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 88,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: entry.value.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final g = entry.value[index];
                                  return SizedBox(
                                    width: 72,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: PhotoTile(
                                            garment: g,
                                            radius: 14,
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => state
                                                .removeFromClothSet(set.id, g),
                                            child: const CircleAvatar(
                                              radius: 11,
                                              backgroundColor: Colors.white,
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => _addFromWardrobe(context, set),
                    child: const Text('Add category'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _uploadPiece(context, set),
                    child: const Text('Upload item'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _edit(context, set),
                    child: const Text('Edit set'),
                  ),
                  TextButton(
                    onPressed: () => _delete(context, set),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFE24B4B)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
