import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/add_item_form_dialog.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'add_clothes_screen.dart';
import 'garment_detail_screen.dart';

class ClosetScreen extends StatelessWidget {
  const ClosetScreen({super.key});

  Future<void> _openAddForm(
    BuildContext context, {
    WardrobeCategory? category,
    String? customShelf,
  }) async {
    await showAddItemFormDialog(
      context,
      initialCategory: category,
      initialCustomShelf: customShelf,
    );
  }

  List<_ShelfRowData> _populatedRows(
    List<Garment> garments,
    Wearer wearer,
    List<String> customShelves,
  ) {
    final byShelf = <String, List<Garment>>{};
    for (final garment in garments) {
      byShelf.putIfAbsent(garment.shelfLabel, () => []).add(garment);
    }

    final rows = <_ShelfRowData>[];
    for (final category in wearer.wardrobeCategories) {
      final items = byShelf.remove(category.label);
      if (items != null && items.isNotEmpty) {
        rows.add(
          _ShelfRowData(
            label: category.label,
            icon: category.icon,
            category: category,
            garments: items,
          ),
        );
      }
    }
    for (final custom in customShelves) {
      final items = byShelf.remove(custom);
      if (items != null && items.isNotEmpty) {
        rows.add(
          _ShelfRowData(
            label: custom,
            icon: Icons.category_outlined,
            customShelf: custom,
            garments: items,
          ),
        );
      }
    }
    for (final entry in byShelf.entries) {
      if (entry.value.isEmpty) continue;
      rows.add(
        _ShelfRowData(
          label: entry.key,
          icon: Icons.category_outlined,
          customShelf: entry.key,
          garments: entry.value,
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final rows = _populatedRows(
      state.garments,
      state.profile.wearer,
      state.profile.customShelves,
    );
    final total = state.garments.length;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: const Text('My Wardrobe'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddClothesScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    backgroundColor: AppColors.terracottaSoft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'My outfit',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: ProfileAvatar()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddForm(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add items'),
        ),
        body: rows.isEmpty
            ? _EmptyWardrobe(onAdd: () => _openAddForm(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Text(
                    '$total ${total == 1 ? 'item' : 'items'} · ${rows.length} ${rows.length == 1 ? 'category' : 'categories'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your cupboard',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe each row left to right. Categories appear here only after you add items.',
                  ),
                  const SizedBox(height: 20),
                  for (final row in rows)
                    _CategoryRow(
                      label: row.label,
                      icon: row.icon,
                      garments: row.garments,
                      onAdd: () => _openAddForm(
                        context,
                        category: row.category,
                        customShelf: row.customShelf,
                      ),
                      onOpen: (g) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GarmentDetailScreen(id: g.id),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ShelfRowData {
  const _ShelfRowData({
    required this.label,
    required this.icon,
    required this.garments,
    this.category,
    this.customShelf,
  });

  final String label;
  final IconData icon;
  final WardrobeCategory? category;
  final String? customShelf;
  final List<Garment> garments;
}

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.terracottaSoft,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.checkroom_outlined,
                size: 40,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cupboard is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Add items, pick a category, and upload a photo. That category row appears here once saved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add items'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.garments,
    required this.onAdd,
    required this.onOpen,
  });

  final String label;
  final IconData icon;
  final List<Garment> garments;
  final VoidCallback onAdd;
  final void Function(Garment garment) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.terracottaSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.terracotta, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label  ·  ${garments.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAdd,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: garments.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == garments.length) {
                  return _AddTile(onAdd: onAdd);
                }
                final garment = garments[index];
                return GestureDetector(
                  onTap: () => onOpen(garment),
                  onDoubleTap: () => showPhotoZoom(context, garment),
                  child: SizedBox(
                    width: 92,
                    height: 118,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: PhotoTile(
                        garment: garment,
                        radius: 18,
                        fit: BoxFit.contain,
                        backgroundColor: const Color(0xFFF3EBE3),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 76,
        height: 118,
        decoration: BoxDecoration(
          color: AppColors.terracottaSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.terracotta),
            SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
