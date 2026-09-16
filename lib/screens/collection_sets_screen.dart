import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/closet_add.dart';
import '../widgets/common.dart';
import '../widgets/settings_button.dart';
import '../widgets/swipe_arrow_row.dart';
import 'garment_detail_screen.dart';
import 'garment_editor_screen.dart';

enum _BrowseMode { singles, sets }

class CollectionSetsScreen extends StatefulWidget {
  const CollectionSetsScreen({super.key, required this.collection});

  final StyleCollection collection;

  @override
  State<CollectionSetsScreen> createState() => _CollectionSetsScreenState();
}

class _CollectionSetsScreenState extends State<CollectionSetsScreen> {
  _BrowseMode _mode = _BrowseMode.singles;
  final Set<String> _collapsedTypes = {};

  StyleCollection get collection => widget.collection;

  Future<void> _addSingle(ClothesType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentEditorScreen(
          initialCategory: type.category,
          initialTopKind: type.topKind,
          assignToCollection: collection,
        ),
      ),
    );
  }

  Future<void> _addPiece(ClothSet set, ClothesType type) async {
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

  Future<void> _showAddMenu(DrapeState state) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to this collection',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.checkroom_outlined),
                title: const Text('Single item'),
                subtitle: const Text('Name, color, type — one piece'),
                onTap: () => Navigator.pop(context, 'single'),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Full set'),
                subtitle: const Text('Group pieces into one look'),
                onTap: () => Navigator.pop(context, 'set'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'set') {
      await state.addClothSet(collection);
      setState(() => _mode = _BrowseMode.sets);
      return;
    }
    await pickClothesType(
      context,
      title: 'Item type',
      onPick: _addSingle,
    );
    if (mounted) setState(() => _mode = _BrowseMode.singles);
  }

  Future<void> _rename(ClothSet set) async {
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
    if (next == null || !mounted) return;
    await context.read<DrapeState>().renameClothSet(set.id, next);
  }

  Future<void> _deleteSet(ClothSet set) async {
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
    if (ok == true && mounted) {
      await context.read<DrapeState>().deleteClothSet(set.id);
    }
  }

  List<Garment> _orderedPieces(List<Garment> pieces) {
    const order = [
      GarmentCategory.dress,
      GarmentCategory.top,
      GarmentCategory.bottom,
      GarmentCategory.outerwear,
      GarmentCategory.shoes,
      GarmentCategory.accessory,
    ];
    final ordered = <Garment>[];
    for (final category in order) {
      for (final g in pieces) {
        if (g.category == category) ordered.add(g);
      }
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final sets = state.setsFor(collection);
    final singles = state.singlesFor(collection);
    final hasContent = state.collectionHasContent(collection);
    final wearerTypes = ClothesType.forWearer(state.profile.wearer);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackIcon(),
        title: Text(collection.label),
        actions: const [SettingsButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(state),
        icon: const Icon(Icons.add),
        label: Text(hasContent ? 'Add' : 'Add first item'),
      ),
      body: !hasContent
          ? _ComingSoonEmpty(onAdd: () => _showAddMenu(state))
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
                const SizedBox(height: 14),
                SegmentedButton<_BrowseMode>(
                  segments: const [
                    ButtonSegment(
                      value: _BrowseMode.singles,
                      label: Text('Singles'),
                      icon: Icon(Icons.checkroom_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: _BrowseMode.sets,
                      label: Text('Sets'),
                      icon: Icon(Icons.layers_outlined, size: 18),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) => setState(() => _mode = v.first),
                ),
                const SizedBox(height: 18),
                if (_mode == _BrowseMode.singles) ...[
                  if (singles.isEmpty)
                    _HintCard(
                      title: 'No single items yet',
                      body:
                          'Add one piece at a time, or switch to Sets for full looks.',
                      actionLabel: 'Add single',
                      onAction: () => pickClothesType(
                        context,
                        title: 'Item type',
                        onPick: _addSingle,
                      ),
                    )
                  else ...[
                    for (final type in wearerTypes)
                      _TypeRowCard(
                        type: type,
                        garments: singles
                            .where((g) => type.matches(g))
                            .toList(),
                        expanded: !_collapsedTypes.contains(type.label),
                        onToggle: () {
                          setState(() {
                            if (_collapsedTypes.contains(type.label)) {
                              _collapsedTypes.remove(type.label);
                            } else {
                              _collapsedTypes.add(type.label);
                            }
                          });
                        },
                        onAdd: () => _addSingle(type),
                        onOpen: (g) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GarmentDetailScreen(id: g.id),
                          ),
                        ),
                      ),
                  ],
                ] else ...[
                  if (sets.isEmpty)
                    _HintCard(
                      title: 'No sets yet',
                      body: 'Create a set, then add each piece with a photo.',
                      actionLabel: 'Add set',
                      onAction: () async {
                        await state.addClothSet(collection);
                      },
                    )
                  else
                    for (var i = 0; i < sets.length; i++)
                      _SetRowCard(
                        set: sets[i],
                        number: i + 1,
                        pieces: _orderedPieces(state.piecesOf(sets[i].outfit)),
                        onAddPiece: (type) => _addPiece(sets[i], type),
                        onRename: () => _rename(sets[i]),
                        onDelete: () => _deleteSet(sets[i]),
                        onRemovePiece: (garment) => state.assignToClothSet(
                          sets[i].id,
                          garment.category,
                          null,
                        ),
                        onOpen: (g) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GarmentDetailScreen(id: g.id),
                          ),
                        ),
                      ),
                ],
              ],
            ),
    );
  }
}

class _ComingSoonEmpty extends StatelessWidget {
  const _ComingSoonEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
              child: Lottie.asset(
                'assets/coming_soon.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nothing here yet. Add a single item or a full set — this animation hides once you add something.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _TypeRowCard extends StatelessWidget {
  const _TypeRowCard({
    required this.type,
    required this.garments,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onOpen,
  });

  final ClothesType type;
  final List<Garment> garments;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Garment garment) onOpen;

  @override
  Widget build(BuildContext context) {
    if (garments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
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
                Icon(type.category.icon, color: AppColors.terracotta, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onToggle,
                    child: Text(
                      '${type.label} · ${garments.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Hide list' : 'Show list',
                  onPressed: onToggle,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 4),
              // Dropdown-style name list
              ...garments.map(
                (g) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: PhotoTile(garment: g, radius: 10),
                  ),
                  title: Text(
                    g.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${g.typeLabel} · ${colorNameOf(g.primaryColor)}',
                  ),
                  onTap: () => onOpen(g),
                ),
              ),
              const SizedBox(height: 8),
              SwipeArrowRow(
                garments: garments,
                onTap: onOpen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetRowCard extends StatelessWidget {
  const _SetRowCard({
    required this.set,
    required this.number,
    required this.pieces,
    required this.onAddPiece,
    required this.onRename,
    required this.onDelete,
    required this.onRemovePiece,
    required this.onOpen,
  });

  final ClothSet set;
  final int number;
  final List<Garment> pieces;
  final void Function(ClothesType type) onAddPiece;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(Garment garment) onRemovePiece;
  final void Function(Garment garment) onOpen;

  @override
  Widget build(BuildContext context) {
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
            SwipeArrowRow(
              garments: pieces,
              emptyLabel: 'Nothing in this set yet. Tap Add.',
              onTap: onOpen,
              onRemove: onRemovePiece,
            ),
          ],
        ),
      ),
    );
  }
}
