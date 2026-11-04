import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';

/// One place to add, delete, and reorder wardrobe categories.
Future<void> showManageCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ManageCategoriesSheet(),
  );
}

class _ManageCategoriesSheet extends StatefulWidget {
  const _ManageCategoriesSheet();

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  late List<String> _order;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(context.read<MineState>().orderedShelfLabels);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  bool _isCustom(MineState state, String label) {
    return state.profile.customShelves.any(
      (e) => e.toLowerCase() == label.toLowerCase(),
    );
  }

  IconData _iconFor(MineState state, String label) {
    for (final c in state.profile.wearer.wardrobeCategories) {
      if (c.label.toLowerCase() == label.toLowerCase()) return c.icon;
    }
    return Icons.category_outlined;
  }

  Future<void> _persistOrder() async {
    await context.read<MineState>().setShelfOrder(_order);
  }

  Future<void> _add() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    final state = context.read<MineState>();
    final exists = [
      ...state.orderedShelfLabels,
      ...state.hiddenBuiltinShelves,
    ].any((e) => e.toLowerCase() == name.toLowerCase());
    if (exists) {
      // If it was only hidden, restore instead of duplicating.
      if (state.hiddenBuiltinShelves
          .any((e) => e.toLowerCase() == name.toLowerCase())) {
        await state.restoreShelf(name);
        if (!mounted) return;
        setState(() {
          _order = List<String>.from(state.orderedShelfLabels);
          _addController.clear();
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That category already exists.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    await state.addCustomShelf(name);
    if (!mounted) return;
    setState(() {
      _order = List<String>.from(state.orderedShelfLabels);
      _addController.clear();
    });
  }

  Future<void> _delete(String label) async {
    final state = context.read<MineState>();
    final custom = _isCustom(state, label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete “$label”?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        content: Text(
          custom
              ? 'Items in this category move to Accessories.'
              : 'This category is removed from your wardrobe. You can restore it later.',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.mediumImpact();
    await state.deleteShelf(label);
    if (!mounted) return;
    setState(() => _order = List<String>.from(state.orderedShelfLabels));
  }

  Future<void> _restore(String label) async {
    HapticFeedback.selectionClick();
    final state = context.read<MineState>();
    await state.restoreShelf(label);
    if (!mounted) return;
    setState(() => _order = List<String>.from(state.orderedShelfLabels));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.78;
    final hidden = state.hiddenBuiltinShelves;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            color: Color(0xFFF6EDE3),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categories',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add, delete, or drag to reorder',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addController,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _add(),
                        decoration: InputDecoration(
                          hintText: 'New category name',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.85),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _add,
                        borderRadius: BorderRadius.circular(16),
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.add_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      sliver: SliverReorderableList(
                        itemCount: _order.length,
                        onReorderItem: (oldIndex, newIndex) async {
                          setState(() {
                            final item = _order.removeAt(oldIndex);
                            _order.insert(newIndex, item);
                          });
                          HapticFeedback.selectionClick();
                          await _persistOrder();
                        },
                        itemBuilder: (context, index) {
                          final label = _order[index];
                          final custom = _isCustom(state, label);
                          return Padding(
                            key: ValueKey(label),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _iconFor(state, label),
                                      color: AppColors.terracotta,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            custom ? 'Custom' : 'Built-in',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(label),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFB42318),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        minimumSize: const Size(0, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Delete',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
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
                    if (hidden.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                          child: Text(
                            'Deleted categories',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, 18 + bottom),
                        sliver: SliverList.separated(
                          itemCount: hidden.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final label = hidden[index];
                            return Material(
                              color: Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 8, 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      _iconFor(state, label),
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _restore(label),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.terracotta,
                                      ),
                                      child: Text(
                                        'Restore',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else
                      SliverToBoxAdapter(
                        child: SizedBox(height: 18 + bottom),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
