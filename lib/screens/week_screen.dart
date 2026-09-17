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
import 'outfit_full_view_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekAnchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekAnchor = DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart => dateOnly(_weekAnchor).subtract(
        Duration(days: _weekAnchor.weekday - DateTime.monday),
      );

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

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

  void _openWardrobe() => goToShellTab?.call(2);

  Future<void> _openEdit(DateTime date, DrapeState state) async {
    final dayEvents = state.eventsOn(date);
    if (dayEvents.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventEditorScreen(existing: dayEvents.first),
        ),
      );
      return;
    }
    final plan = state.week?.forDate(date);
    if (plan != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayLookScreen(date: date)),
      );
    } else {
      _openWardrobe();
    }
  }

  Future<void> _addLook(DateTime date, DrapeState state) async {
    final plan = state.week?.forDate(date);
    if (plan == null) {
      _openWardrobe();
      return;
    }
    if (plan.outfit == null || plan.outfit!.isEmpty) {
      await state.shuffleDay(plan);
    }
    if (!mounted) return;
    await _openEdit(date, state);
  }

  Future<void> _cycleLook(DateTime date, DrapeState state, int dir) async {
    final plan = state.week?.forDate(date);
    if (plan == null) return;
    if (plan.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This look is locked.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    await state.cycleDayLook(plan, dir);
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final days = _weekDays;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                      onAdd: () => _addLook(date, state),
                      onPrev: () => _cycleLook(date, state, -1),
                      onNext: () => _cycleLook(date, state, 1),
                      onOpenPiece: (index) =>
                          _openFullView(date, look.pieces, initialIndex: index),
                      onOpenPhoto: () {
                        if (look.photo != null && look.event != null) {
                          _openEdit(date, state);
                        } else if (look.pieces.isNotEmpty) {
                          _openFullView(date, look.pieces);
                        } else {
                          _addLook(date, state);
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

  bool get hasVisual =>
      photo != null ||
      pieces.any((g) => garmentImageProvider(g.imagePath) != null) ||
      pieces.isNotEmpty;

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

class _DayOutfitCard extends StatelessWidget {
  const _DayOutfitCard({
    required this.date,
    required this.look,
    required this.plan,
    required this.onAdd,
    required this.onPrev,
    required this.onNext,
    required this.onOpenPiece,
    required this.onOpenPhoto,
  });

  final DateTime date;
  final _LookData look;
  final DayPlan? plan;
  final VoidCallback onAdd;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onOpenPiece;
  final VoidCallback onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final hasLook = look.hasVisual;
    final locked = plan?.locked ?? false;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: hasLook ? onOpenPhoto : onAdd,
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
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _IconAction(
                      tooltip: 'Previous look',
                      icon: Icons.chevron_left_rounded,
                      onTap: plan == null || locked ? null : onPrev,
                      filled: true,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 78,
                        child: hasLook
                            ? _LookRow(
                                look: look,
                                onOpenPiece: onOpenPiece,
                                onOpenPhoto: onOpenPhoto,
                              )
                            : _EmptyLookRow(onAdd: onAdd),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _IconAction(
                      tooltip: 'Next look',
                      icon: Icons.chevron_right_rounded,
                      onTap: plan == null || locked ? null : onNext,
                      filled: true,
                    ),
                  ],
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
            height: 78,
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
        final photo = garmentImageProvider(g.imagePath);
        return GestureDetector(
          onTap: () => onOpenPiece(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 78,
              child: photo != null
                  ? Image(image: photo, fit: BoxFit.cover)
                  : ColoredBox(
                      color: g.primaryColor,
                      child: Icon(
                        g.category.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyLookRow extends StatelessWidget {
  const _EmptyLookRow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.terracottaSoft.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.terracotta),
            ),
            const SizedBox(width: 10),
            Text(
              'Add or select look',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = color ?? (enabled ? AppColors.ink : AppColors.line);

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: enabled
                  ? AppColors.parchment
                  : AppColors.line.withValues(alpha: 0.35),
              foregroundColor: fg,
            )
          : null,
      icon: Icon(icon, size: filled ? 22 : 20, color: fg),
    );
  }
}
