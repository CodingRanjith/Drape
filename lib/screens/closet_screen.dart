import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/closet_add.dart';
import '../widgets/common.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'add_clothes_screen.dart';
import 'garment_detail_screen.dart';
import 'garment_editor_screen.dart';

class ClosetScreen extends StatelessWidget {
  const ClosetScreen({super.key});

  Future<void> _addCategoryWise(BuildContext context) async {
    await pickClothesType(
      context,
      title: 'Add by category',
      onPick: (type) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GarmentEditorScreen(
              initialCategory: type.category,
              initialTopKind: type.topKind,
            ),
          ),
        );
      },
    );
  }

  Future<void> _addForType(BuildContext context, ClothesType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentEditorScreen(
          initialCategory: type.category,
          initialTopKind: type.topKind,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final types = ClothesType.forWearer(state.profile.wearer);
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
          onPressed: () => _addCategoryWise(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(
              total == 0
                  ? 'Your wardrobe is empty'
                  : '$total ${total == 1 ? 'item' : 'items'} across categories',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Browse by category',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Each row is one clothing type. Swipe sideways to see more, or tap Add to grow that row.',
            ),
            const SizedBox(height: 18),
            for (final type in types)
              _CategoryRow(
                type: type,
                garments: state.garments.where(type.matches).toList(),
                onAdd: () => _addForType(context, type),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.type,
    required this.garments,
    required this.onAdd,
    required this.onOpen,
  });

  final ClothesType type;
  final List<Garment> garments;
  final VoidCallback onAdd;
  final void Function(Garment garment) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(type.category.icon, color: AppColors.terracotta, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${type.label} · ${garments.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: garments.isEmpty ? 1 : garments.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (garments.isEmpty) {
                  return _EmptyTile(onAdd: onAdd);
                }
                if (index == garments.length) {
                  return _AddTile(onAdd: onAdd);
                }
                final garment = garments[index];
                return GestureDetector(
                  onTap: () => onOpen(garment),
                  onDoubleTap: () => showPhotoZoom(context, garment),
                  child: SizedBox(
                    width: 88,
                    height: 108,
                    child: PhotoTile(garment: garment, radius: 16),
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

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        height: 108,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.terracotta),
            SizedBox(height: 6),
            Text(
              'Add',
              style: TextStyle(
                fontWeight: FontWeight.w700,
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

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        height: 108,
        decoration: BoxDecoration(
          color: AppColors.terracottaSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.terracotta),
      ),
    );
  }
}
