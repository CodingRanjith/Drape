import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

Future<T?> _showCenterPopup<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 420,
  double heightFactor = 0.78,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x664A3F36),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, anim, secondary) {
      final size = MediaQuery.sizeOf(context);
      final inset = MediaQuery.viewInsetsOf(context);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              12 + inset.bottom,
            ),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: (size.width - 36).clamp(280.0, maxWidth),
                height: size.height * heightFactor,
                child: child,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PopupShell extends StatelessWidget {
  const _PopupShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFBF7),
            Color(0xFFF8F1EA),
            Color(0xFFF3E1D4),
          ],
        ),
        border: Border.all(color: AppColors.clay.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Centered popup: Create set | Select set for a week day.
Future<void> showWeekDayLookSheet(BuildContext context, DayPlan day) async {
  HapticFeedback.selectionClick();
  final label = DateFormat('EEEE, d MMM').format(day.date);
  final choice = await _showCenterPopup<_LookChoice>(
    context: context,
    heightFactor: 0.34,
    child: _PopupShell(
      title: 'Add look',
      subtitle: label,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Builder(
          builder: (dialogContext) {
            return Row(
              children: [
                Expanded(
                  child: _IconChoice(
                    icon: Icons.grid_view_rounded,
                    label: 'Create set',
                    onTap: () =>
                        Navigator.pop(dialogContext, _LookChoice.create),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IconChoice(
                    icon: Icons.layers_outlined,
                    label: 'Select set',
                    onTap: () =>
                        Navigator.pop(dialogContext, _LookChoice.select),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == _LookChoice.create) {
    await showWeekCreateSetSheet(context, day);
  } else {
    await showWeekSelectSetSheet(context, day);
  }
}

enum _LookChoice { create, select }

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.clay.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.terracottaSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.terracotta),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.ink,
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

/// Create set: wardrobe categories → pick items (2-col) → save to day.
Future<void> showWeekCreateSetSheet(BuildContext context, DayPlan day) async {
  await _showCenterPopup<void>(
    context: context,
    heightFactor: 0.88,
    child: _WeekCreateSetSheet(day: day),
  );
}

class _WeekCreateSetSheet extends StatefulWidget {
  const _WeekCreateSetSheet({required this.day});

  final DayPlan day;

  @override
  State<_WeekCreateSetSheet> createState() => _WeekCreateSetSheetState();
}

class _WeekCreateSetSheetState extends State<_WeekCreateSetSheet> {
  /// One picked garment per wardrobe category/shelf.
  final Map<String, Garment> _pickedByShelf = {};
  String? _activeShelf;
  var _saving = false;

  Future<void> _save() async {
    if (_pickedByShelf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item.')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final state = context.read<MineState>();
      final ok = await state.assignPiecesToDay(
        widget.day,
        _pickedByShelf.values.map((g) => g.id).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Some pieces are already planned on another day this week.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final shelves = state.populatedShelves();
    final activeItems = shelves
        .where((s) => s.label == _activeShelf)
        .expand((s) => s.items)
        .where(
          (g) =>
              !g.inLaundry &&
              g.imagePath != null &&
              g.imagePath!.trim().isNotEmpty,
        )
        .toList();

    return _PopupShell(
      title: 'Create set',
      subtitle: _pickedByShelf.isEmpty
          ? 'Add wear from your wardrobe'
          : '${_pickedByShelf.length} pieces selected',
      footer: _saving
          ? const Center(child: CircularProgressIndicator())
          : FilledButton(
              onPressed: shelves.isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Save to day',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pickedByShelf.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final entry in _pickedByShelf.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 58,
                          child: Stack(
                            children: [
                              PhotoTile(garment: entry.value, radius: 12),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _pickedByShelf.remove(entry.key);
                                  }),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (shelves.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No wardrobe items yet. Add clothes in My Wardrobe first.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(color: AppColors.muted),
                  ),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(
                  '${_activeShelf ?? 'none'}-${shelves.map((s) => s.label).join(',')}',
                ),
                initialValue: shelves.any((s) => s.label == _activeShelf)
                    ? _activeShelf
                    : null,
                decoration: InputDecoration(
                  labelText: 'Add wear',
                  hintText: 'Select wardrobe category',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.85),
                ),
                items: [
                  for (final shelf in shelves)
                    DropdownMenuItem(
                      value: shelf.label,
                      child: Text(
                        '${shelf.label} (${shelf.items.length})'
                        '${_pickedByShelf.containsKey(shelf.label) ? ' · added' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  HapticFeedback.selectionClick();
                  setState(() => _activeShelf = value);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _activeShelf == null
                    ? Center(
                        child: Text(
                          'Select a category above, then tap an item to add.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(color: AppColors.muted),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: activeItems.length,
                        itemBuilder: (context, index) {
                          final g = activeItems[index];
                          final selected =
                              _pickedByShelf[_activeShelf]?.id == g.id;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _pickedByShelf[_activeShelf!] = g;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.terracotta
                                      : AppColors.clay.withValues(alpha: 0.55),
                                  width: selected ? 2.2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    PhotoTile(garment: g, radius: 0),
                                    if (selected)
                                      const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.terracotta,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          16,
                                          8,
                                          8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              AppColors.ink.withValues(
                                                alpha: 0.55,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          g.name.isEmpty
                                              ? g.typeLabel
                                              : g.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
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
          ],
        ),
      ),
    );
  }
}

/// Select set: collection page grid → existing sets → assign to day.
Future<void> showWeekSelectSetSheet(BuildContext context, DayPlan day) async {
  await _showCenterPopup<void>(
    context: context,
    heightFactor: 0.88,
    child: _WeekSelectSetSheet(day: day),
  );
}

class _WeekSelectSetSheet extends StatefulWidget {
  const _WeekSelectSetSheet({required this.day});

  final DayPlan day;

  @override
  State<_WeekSelectSetSheet> createState() => _WeekSelectSetSheetState();
}

class _WeekSelectSetSheetState extends State<_WeekSelectSetSheet> {
  StyleCollection? _opened;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final wearer = state.profile.wearer;
    final available = state.availableSetsForDay(widget.day);

    if (_opened != null) {
      final sets = available.where((s) => s.collection == _opened).toList();
      return _PopupShell(
        title: _opened!.label,
        subtitle: sets.isEmpty
            ? 'No free sets in this collection'
            : '${sets.length} ${sets.length == 1 ? 'set' : 'sets'} available',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _opened = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    'Collections',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.terracotta,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: sets.isEmpty
                    ? Center(
                        child: Text(
                          'No created sets here yet, or all are used this week.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final set = sets[index];
                          final pieces = state.piecesOf(set.outfit);
                          return Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await state.assignSetToDay(
                                  widget.day,
                                  set,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                if (!ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'That set uses items already planned this week.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.clay.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: pieces.isEmpty
                                            ? const Icon(
                                                Icons.layers_outlined,
                                                color: AppColors.terracotta,
                                              )
                                            : PhotoTile(
                                                garment: pieces.first,
                                                radius: 14,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              set.name,
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${pieces.length} pieces · tap to add',
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.add_circle_rounded,
                                        color: AppColors.terracotta,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return _PopupShell(
      title: 'Select set',
      subtitle: 'Open a collection, then pick a created set',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            for (final collection in StyleCollection.values)
              _CollectionPickCard(
                collection: collection,
                wearer: wearer,
                setCount: state.setsFor(collection).length,
                freeCount: available
                    .where((s) => s.collection == collection)
                    .length,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _opened = collection);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPickCard extends StatelessWidget {
  const _CollectionPickCard({
    required this.collection,
    required this.wearer,
    required this.setCount,
    required this.freeCount,
    required this.onTap,
  });

  final StyleCollection collection;
  final Wearer wearer;
  final int setCount;
  final int freeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = collection.coverAssetFor(wearer);
    final status = setCount == 0
        ? 'No sets yet'
        : (freeCount == 0
            ? '$setCount sets · all used'
            : '$freeCount free · $setCount total');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                cover,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: collection.coverGradient.first,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      collection.coverGradient.first.withValues(alpha: 0.4),
                      collection.coverGradient.last.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(collection.icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      collection.label,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
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

