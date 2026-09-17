import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'event_editor_screen.dart';
import 'garment_detail_screen.dart';
import 'outfit_full_view_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekAnchor;
  var _didAutoSuggest = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekAnchor = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSuggest());
  }

  DateTime get _weekStart => dateOnly(_weekAnchor).subtract(
        Duration(days: _weekAnchor.weekday - DateTime.monday),
      );

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _maybeSuggest() async {
    if (_didAutoSuggest || !mounted) return;
    final state = context.read<DrapeState>();
    if (state.suggestableLookCount < 7) return;
    _didAutoSuggest = true;
    // 14+: reshuffle for a fresh different set each day this week.
    await state.suggestWeekSets(reshuffle: state.suggestableLookCount >= 14);
  }

  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(() {
      _weekAnchor = dateOnly(_weekAnchor.add(Duration(days: 7 * weeks)));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekAnchor,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    setState(() {
      _weekAnchor = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _openEdit(DateTime date, DrapeState state) async {
    final dayEvents = state.eventsOn(date);
    if (dayEvents.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(existing: dayEvents.first),
      ),
    );
  }

  void _openFullView(
    DateTime date,
    List<Garment> pieces, {
    int initialIndex = 0,
  }) {
    if (pieces.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OutfitFullViewScreen(
          pieces: pieces,
          date: date,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _pickShelf(
    DateTime date,
    _WeekShelf shelf,
    DrapeState state,
  ) async {
    final plan = state.week?.forDate(date);
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Looks can only be edited for the current week.'),
        ),
      );
      return;
    }
    if (plan.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock this day before changing items.')),
      );
      return;
    }

    final used = {
      for (final d in state.week!.days)
        if (!sameDay(d.date, plan.date)) ...?d.outfit?.pieceIds,
    };
    final options = state.garments
        .where((g) => shelf.matches(g) && !g.inLaundry)
        .toList();
    final available = options.where((g) => !used.contains(g.id)).toList();
    final taken = options.where((g) => used.contains(g.id)).toList();
    final selected = shelf.selectedOn(plan, state);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _ShelfZoomPicker(
          shelf: shelf,
          plan: plan,
          state: state,
          selected: selected,
          available: available,
          taken: taken,
          hostContext: context,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final days = _weekDays;
    final lookCount = state.suggestableLookCount;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: lookCount >= 7
            ? FloatingActionButton.extended(
                onPressed: () => state.suggestWeekSets(reshuffle: true),
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.casino_outlined),
                label: Text(
                  lookCount >= 14 ? 'New random week' : 'Suggest week',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    const AppBackIcon(),
                    Expanded(
                      child: Text(
                        'This week',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: ProfileAvatar(radius: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _WeekNav(
                  weekStart: _weekStart,
                  onPrev: () => _shiftWeek(-1),
                  onNext: () => _shiftWeek(1),
                  onPickDate: _pickDate,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    lookCount >= 7 ? 88 : 24,
                  ),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final date = days[i];
                    final look = _LookData.resolve(state, date);
                    final plan = state.week?.forDate(date);
                    return _DayOutfitCard(
                      date: date,
                      look: look,
                      plan: plan,
                      state: state,
                      onPickShelf: (shelf) => _pickShelf(date, shelf, state),
                      onOpenPiece: (index) => _openFullView(
                        date,
                        look.pieces,
                        initialIndex: index,
                      ),
                      onOpenPhoto: () {
                        if (look.photo != null && look.event != null) {
                          _openEdit(date, state);
                        } else if (look.pieces.isNotEmpty) {
                          _openFullView(date, look.pieces);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfZoomPicker extends StatefulWidget {
  const _ShelfZoomPicker({
    required this.shelf,
    required this.plan,
    required this.state,
    required this.selected,
    required this.available,
    required this.taken,
    required this.hostContext,
  });

  final _WeekShelf shelf;
  final DayPlan plan;
  final DrapeState state;
  final Garment? selected;
  final List<Garment> available;
  final List<Garment> taken;
  final BuildContext hostContext;

  @override
  State<_ShelfZoomPicker> createState() => _ShelfZoomPickerState();
}

class _ShelfZoomPickerState extends State<_ShelfZoomPicker> {
  late bool _replacing;
  Garment? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.selected;
    _replacing = widget.selected == null;
  }

  Future<void> _assign(Garment g) async {
    final messenger = ScaffoldMessenger.maybeOf(widget.hostContext);
    final ok = await widget.state.assignPiece(
      widget.plan,
      g.category,
      g.id,
      topKind: g.topKind,
    );
    if (!mounted) return;
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'That item is already planned another day this week.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _current = g;
      _replacing = false;
    });
  }

  Future<void> _remove() async {
    final current = _current;
    if (current == null) return;
    await widget.state.clearGarmentFromDay(widget.plan, current);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openDetail(Garment g) {
    Navigator.pop(context);
    Navigator.of(widget.hostContext).push(
      MaterialPageRoute(builder: (_) => GarmentDetailScreen(id: g.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final photo = _current == null
        ? null
        : garmentImageProvider(_current!.imagePath);
    final showList = _replacing || _current == null;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width.clamp(280.0, 420.0),
            maxHeight: size.height * 0.88,
          ),
          child: Material(
            color: AppColors.paper,
            elevation: 16,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.shelf.label,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (_current != null)
                        IconButton(
                          tooltip: 'Replace',
                          onPressed: () => setState(() => _replacing = true),
                          icon: Icon(
                            Icons.swap_horiz_rounded,
                            color: _replacing
                                ? AppColors.terracotta
                                : AppColors.ink,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    showList
                        ? 'Only items from this category. Tap one to use it.'
                        : 'Tap replace to change this item.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (!showList) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: photo == null
                            ? ColoredBox(
                                color: AppColors.terracottaSoft,
                                child: Center(
                                  child: Icon(
                                    widget.shelf.icon,
                                    size: 56,
                                    color: AppColors.terracotta,
                                  ),
                                ),
                              )
                            : Image(
                                image: photo,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: _remove,
                          icon: const Icon(Icons.hide_source_outlined, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _openDetail(_current!),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Details'),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Expanded(
                    child: widget.available.isEmpty && widget.taken.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Nothing in ${widget.shelf.label} yet. Add pieces in My Wardrobe.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            children: [
                              ...widget.available.map(
                                (g) => ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  selected: _current?.id == g.id,
                                  selectedTileColor: AppColors.terracottaSoft
                                      .withValues(alpha: 0.55),
                                  leading: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: PhotoTile(garment: g, radius: 12),
                                  ),
                                  title: Text(
                                    g.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(g.typeLabel),
                                  trailing: IconButton(
                                    tooltip: 'Open',
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                    ),
                                    onPressed: () => _openDetail(g),
                                  ),
                                  onTap: () => _assign(g),
                                ),
                              ),
                              if (widget.taken.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    'Already used this week',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                ...widget.taken.map(
                                  (g) => ListTile(
                                    enabled: false,
                                    leading: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Opacity(
                                        opacity: 0.45,
                                        child: PhotoTile(
                                          garment: g,
                                          radius: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(g.name),
                                    subtitle: const Text(
                                      'Planned on another day',
                                    ),
                                  ),
                                ),
                              ],
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

class _WeekNav extends StatelessWidget {
  const _WeekNav({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Week of ${DateFormat('d MMM').format(weekStart)}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _LookData {
  const _LookData({
    this.photo,
    this.pieces = const [],
    this.event,
  });

  final ImageProvider? photo;
  final List<Garment> pieces;
  final LifeEvent? event;

  bool get hasVisual => photo != null || pieces.isNotEmpty;

  static List<Garment> _uploadedPieces(Iterable<Garment> garments) {
    return garments
        .where((g) => garmentImageProvider(g.imagePath) != null)
        .toList();
  }

  static _LookData resolve(DrapeState state, DateTime date) {
    final events = state.eventsOn(date);
    for (final event in events) {
      final look = state.partyLookById(event.partyLookId);
      final photo = garmentImageProvider(look?.imagePath);
      if (photo != null) {
        return _LookData(photo: photo, event: event);
      }
    }
    for (final event in events) {
      final clothes = _uploadedPieces(
        event.garmentIds.map(state.garmentById).whereType<Garment>(),
      );
      if (clothes.isNotEmpty) {
        return _LookData(pieces: clothes, event: event);
      }
    }
    final plan = state.week?.forDate(date);
    return _LookData(pieces: _uploadedPieces(state.piecesOf(plan?.outfit)));
  }
}

class _WeekShelf {
  const _WeekShelf({
    required this.label,
    required this.icon,
    this.category,
    this.customShelf,
  });

  final String label;
  final IconData icon;
  final WardrobeCategory? category;
  final String? customShelf;

  bool matches(Garment g) => g.shelfLabel == label;

  Garment? selectedOn(DayPlan? plan, DrapeState state) {
    final outfit = plan?.outfit;
    if (outfit == null) return null;
    for (final id in outfit.pieceIds) {
      final g = state.garmentById(id);
      if (g != null && matches(g)) return g;
    }
    return null;
  }

  static List<_WeekShelf> allFor(
    Wearer wearer,
    List<String> customShelves,
  ) {
    final shelves = <_WeekShelf>[
      for (final category in wearer.wardrobeCategories)
        _WeekShelf(
          label: category.label,
          icon: category.icon,
          category: category,
        ),
    ];
    final seen = {for (final s in shelves) s.label.toLowerCase()};
    for (final custom in customShelves) {
      final label = custom.trim();
      if (label.isEmpty) continue;
      if (!seen.add(label.toLowerCase())) continue;
      shelves.add(
        _WeekShelf(
          label: label,
          icon: Icons.category_outlined,
          customShelf: label,
        ),
      );
    }
    return shelves;
  }
}

class _DayOutfitCard extends StatelessWidget {
  const _DayOutfitCard({
    required this.date,
    required this.look,
    required this.plan,
    required this.state,
    required this.onPickShelf,
    required this.onOpenPiece,
    required this.onOpenPhoto,
  });

  final DateTime date;
  final _LookData look;
  final DayPlan? plan;
  final DrapeState state;
  final ValueChanged<_WeekShelf> onPickShelf;
  final ValueChanged<int> onOpenPiece;
  final VoidCallback onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final locked = plan?.locked ?? false;
    final eventLook = look.event != null && look.hasVisual;
    final shelves = _WeekShelf.allFor(
      state.profile.wearer,
      state.profile.customShelves,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          DateFormat('d MMM').format(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    const Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (eventLook)
                SizedBox(
                  height: 88,
                  child: _LookRow(
                    look: look,
                    onOpenPiece: onOpenPiece,
                    onOpenPhoto: onOpenPhoto,
                  ),
                )
              else
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shelves.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final shelf = shelves[i];
                      final garment = shelf.selectedOn(plan, state);
                      return _CategorySlot(
                        shelf: shelf,
                        garment: garment,
                        onTap: () => onPickShelf(shelf),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySlot extends StatelessWidget {
  const _CategorySlot({
    required this.shelf,
    required this.garment,
    required this.onTap,
  });

  final _WeekShelf shelf;
  final Garment? garment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo =
        garment == null ? null : garmentImageProvider(garment!.imagePath);
    return Material(
      color: AppColors.parchment.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: photo == null
                        ? ColoredBox(
                            color: AppColors.terracottaSoft,
                            child: Center(
                              child: Icon(
                                Icons.add_rounded,
                                color: AppColors.terracotta,
                                size: 28,
                              ),
                            ),
                          )
                        : Image(
                            image: photo,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  shelf.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _LookRow extends StatelessWidget {
  const _LookRow({
    required this.look,
    required this.onOpenPiece,
    required this.onOpenPhoto,
  });

  final _LookData look;
  final ValueChanged<int> onOpenPiece;
  final VoidCallback onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    if (look.photo != null) {
      return GestureDetector(
        onTap: onOpenPhoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image(
            image: look.photo!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 88,
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: look.pieces.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final g = look.pieces[i];
        final photo = garmentImageProvider(g.imagePath)!;
        return GestureDetector(
          onTap: () => onOpenPiece(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 68,
              height: 88,
              child: Image(image: photo, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
