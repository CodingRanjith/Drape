import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_nav.dart';
import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/garment_photo.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'day_look_screen.dart';
import 'event_editor_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart => dateOnly(_selected).subtract(
        Duration(days: _selected.weekday - DateTime.monday),
      );

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = dateOnly(_selected.add(Duration(days: 7 * weeks)));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    setState(() {
      _selected = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _selectDay(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() => _selected = dateOnly(date));
  }

  void _openWardrobe() => goToShellTab?.call(2);

  Future<void> _openLook(DrapeState state) async {
    final dayEvents = state.eventsOn(_selected);
    if (dayEvents.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventEditorScreen(existing: dayEvents.first),
        ),
      );
      return;
    }
    final plan = state.week?.forDate(_selected);
    if (plan != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayLookScreen(date: _selected)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final look = _LookData.resolve(state, _selected);

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    children: [
                      _WeekNav(
                        weekStart: _weekStart,
                        onPrev: () => _shiftWeek(-1),
                        onNext: () => _shiftWeek(1),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            DateFormat('EEEE').format(_selected),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 320,
                              maxHeight: 480,
                            ),
                            child: AspectRatio(
                              aspectRatio: 3 / 4.25,
                              child: _LookFrame(
                                look: look,
                                weekday: DateFormat('EEEE').format(_selected),
                                onOpen: () => _openLook(state),
                                onAddClothes: _openWardrobe,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (final day in _weekDays)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: _DateChip(
                                  date: day,
                                  selected: sameDay(day, _selected),
                                  marked:
                                      _LookData.resolve(state, day).hasVisual,
                                  onTap: () => _selectDay(day),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openWardrobe,
                          icon: const Icon(Icons.checkroom_outlined, size: 20),
                          label: const Text('Go to the wardrobe'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const StadiumBorder(),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _WeekNav extends StatelessWidget {
  const _WeekNav({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;

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
          child: Text(
            'Week of ${DateFormat('d MMM').format(weekStart)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
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

  bool get hasVisual =>
      photo != null ||
      pieces.any((g) => garmentImageProvider(g.imagePath) != null);

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
      final clothes = event.garmentIds
          .map(state.garmentById)
          .whereType<Garment>()
          .toList();
      if (clothes.isNotEmpty) {
        return _LookData(pieces: clothes, event: event);
      }
    }
    final plan = state.week?.forDate(date);
    return _LookData(pieces: state.piecesOf(plan?.outfit));
  }
}

class _LookFrame extends StatelessWidget {
  const _LookFrame({
    required this.look,
    required this.weekday,
    required this.onOpen,
    required this.onAddClothes,
  });

  final _LookData look;
  final String weekday;
  final VoidCallback onOpen;
  final VoidCallback onAddClothes;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(44),
      child: InkWell(
        onTap: look.hasVisual ? onOpen : onAddClothes,
        borderRadius: BorderRadius.circular(44),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(44),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: look.hasVisual
                ? _LookVisual(look: look)
                : _EmptyLook(weekday: weekday),
          ),
        ),
      ),
    );
  }
}

class _EmptyLook extends StatelessWidget {
  const _EmptyLook({required this.weekday});

  final String weekday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.terracottaSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              color: AppColors.terracotta,
              size: 38,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No outfit for $weekday',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No look planned for this day yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LookVisual extends StatelessWidget {
  const _LookVisual({required this.look});

  final _LookData look;

  @override
  Widget build(BuildContext context) {
    if (look.photo != null) {
      return Image(
        image: look.photo!,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.2),
        width: double.infinity,
        height: double.infinity,
      );
    }

    final photos = look.pieces
        .where((g) => garmentImageProvider(g.imagePath) != null)
        .toList();
    if (photos.length == 1) {
      return Image(
        image: garmentImageProvider(photos.first.imagePath)!,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.2),
        width: double.infinity,
        height: double.infinity,
      );
    }

    final dress = photos.where((g) => g.category == GarmentCategory.dress);
    final tops = photos.where((g) => g.category == GarmentCategory.top);
    final bottoms = photos.where((g) => g.category == GarmentCategory.bottom);
    final extras = photos.where(
      (g) =>
          g.category == GarmentCategory.outerwear ||
          g.category == GarmentCategory.shoes ||
          g.category == GarmentCategory.accessory,
    );

    final stack = <Garment>[
      ...dress,
      ...tops,
      ...bottoms,
      ...extras,
    ];
    if (stack.isEmpty) stack.addAll(photos);

    return Column(
      children: [
        for (final piece in stack.take(3))
          Expanded(
            flex: piece.category == GarmentCategory.shoes ? 2 : 3,
            child: Image(
              image: garmentImageProvider(piece.imagePath)!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('MMM').format(date),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white70 : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd').format(date),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: marked
                    ? (selected ? Colors.white : AppColors.terracotta)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
