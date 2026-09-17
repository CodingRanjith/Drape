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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Looks can only be edited for the current week.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayLookScreen(date: date)),
    );
  }

  Future<void> _removeLook(DateTime date, DrapeState state) async {
    final plan = state.week?.forDate(date);
    if (plan == null || plan.outfit == null) return;
    if (plan.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock this day before removing.')),
      );
      return;
    }
    await state.clearDayOutfit(plan);
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
              if (lookCount > 0 && lookCount < 7)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Upload ${7 - lookCount} more set${7 - lookCount == 1 ? '' : 's'} for auto week suggestions.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
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
                      onAdd: () => _addLook(date, state),
                      onRemove: () => _removeLook(date, state),
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

class _DayOutfitCard extends StatelessWidget {
  const _DayOutfitCard({
    required this.date,
    required this.look,
    required this.plan,
    required this.onAdd,
    required this.onRemove,
    required this.onOpenPiece,
    required this.onOpenPhoto,
  });

  final DateTime date;
  final _LookData look;
  final DayPlan? plan;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<int> onOpenPiece;
  final VoidCallback onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final hasLook = look.hasVisual;
    final locked = plan?.locked ?? false;

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
              // Center: add or remove that day's wear set
              SizedBox(
                height: 88,
                child: hasLook
                    ? Row(
                        children: [
                          Expanded(
                            child: _LookRow(
                              look: look,
                              onOpenPiece: onOpenPiece,
                              onOpenPhoto: onOpenPhoto,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CenterAction(
                            icon: Icons.remove_rounded,
                            label: 'Remove',
                            color: AppColors.terracotta,
                            onTap: locked ? null : onRemove,
                          ),
                        ],
                      )
                    : Center(
                        child: _CenterAction(
                          icon: Icons.add_rounded,
                          label: 'Add set',
                          color: AppColors.ink,
                          wide: true,
                          onTap: onAdd,
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

class _CenterAction extends StatelessWidget {
  const _CenterAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? color.withValues(alpha: wide ? 0.08 : 0.1)
          : AppColors.line.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: wide ? 160 : 72,
          height: wide ? 72 : 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: enabled ? color : AppColors.muted, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: enabled ? color : AppColors.muted,
                ),
              ),
            ],
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
