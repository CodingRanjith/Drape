import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Create or edit a named set by picking pieces from wardrobe categories.
Future<bool> showCreateSetSheet(
  BuildContext context, {
  required StyleCollection collection,
  ClothSet? existing,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (context) => _CreateSetSheet(
      collection: collection,
      existing: existing,
    ),
  );
  return created == true;
}

class _CreateSetSheet extends StatefulWidget {
  const _CreateSetSheet({
    required this.collection,
    this.existing,
  });

  final StyleCollection collection;
  final ClothSet? existing;

  @override
  State<_CreateSetSheet> createState() => _CreateSetSheetState();
}

class _CreateSetSheetState extends State<_CreateSetSheet> {
  late final TextEditingController _name;
  final Map<String, Garment> _pickedByShelf = {};
  String? _activeShelf;
  var _saving = false;
  var _filled = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final existing = widget.existing;
    if (existing == null) return;
    final state = context.read<MineState>();
    for (final garment in state.piecesOf(existing.outfit)) {
      _pickedByShelf[garment.shelfLabel] = garment;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pickedByShelf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one item for this set.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ids = _pickedByShelf.values.map((g) => g.id).toList();
      final state = context.read<MineState>();
      if (_editing) {
        await state.replaceClothSetPieces(
          widget.existing!.id,
          name: _name.text.trim(),
          garmentIds: ids,
        );
      } else {
        await state.addClothSet(
          widget.collection,
          name: _name.text.trim(),
          garmentIds: ids,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final shelves = state.populatedShelves();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final available = shelves
        .where((s) => !_pickedByShelf.containsKey(s.label))
        .toList();
    ({String label, List<Garment> items})? active;
    for (final shelf in shelves) {
      if (shelf.label == _activeShelf) {
        active = shelf;
        break;
      }
    }
    final activeItems = active?.items ?? const <Garment>[];
    final activeLabel = active?.label;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing ? 'Edit set' : 'New set',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.collection.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Set name',
                hintText: 'e.g. Monday office look',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pieces in this set',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (_pickedByShelf.isEmpty)
              const Text(
                'Choose a wardrobe category (Topwear, Bottomwear…), then tap an item. Add another category for more pieces.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final entry in _pickedByShelf.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 78,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    PhotoTile(garment: entry.value, radius: 14),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(() {
                                          _pickedByShelf.remove(entry.key);
                                          if (_activeShelf == entry.key) {
                                            _activeShelf = null;
                                          }
                                        }),
                                        child: const CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.white,
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Wardrobe category',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            if (shelves.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No wardrobe items yet. Add clothes in My Wardrobe first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else ...[
              if (available.isEmpty && _activeShelf == null)
                const Text(
                  'Every wardrobe category with items is already in this set.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${_activeShelf ?? 'none'}-${available.map((s) => s.label).join(',')}',
                  ),
                  initialValue: available.any((s) => s.label == _activeShelf)
                      ? _activeShelf
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'Select wardrobe category',
                  ),
                  items: [
                    for (final shelf in available)
                      DropdownMenuItem(
                        value: shelf.label,
                        child: Text(
                          '${shelf.label} (${shelf.items.length})',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _activeShelf = value);
                  },
                ),
              const SizedBox(height: 12),
              Expanded(
                child: activeLabel == null
                    ? const Center(
                        child: Text(
                          'Select a wardrobe category to see its items.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: activeItems.length,
                        itemBuilder: (context, index) {
                          final garment = activeItems[index];
                          final selected =
                              _pickedByShelf[activeLabel]?.id == garment.id;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _pickedByShelf[activeLabel] = garment;
                                _activeShelf = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.terracotta
                                      : AppColors.line,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    PhotoTile(garment: garment, radius: 0),
                                    if (selected)
                                      const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.terracotta,
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.black54,
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          garment.name.isEmpty
                                              ? garment.typeLabel
                                              : garment.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
            const SizedBox(height: 12),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: shelves.isEmpty ? null : _save,
                      child: Text(_editing ? 'Save set' : 'Create set'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
