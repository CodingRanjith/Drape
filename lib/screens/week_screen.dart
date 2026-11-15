import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mine_logo_mark.dart';
import '../widgets/page_background.dart';
import '../widgets/week_day_look_sheet.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, this.embedded = false});

  /// Inside the calendar Week tab. The parent owns the title and button.
  final bool embedded;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekAnchor;
  var _didAutoSuggest = false;
  DateTime? _focusDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekAnchor = DateTime(now.year, now.month, now.day);
    _focusDay = dateOnly(now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSuggest());
  }

  DateTime get _weekStart => dateOnly(_weekAnchor).subtract(
        Duration(days: _weekAnchor.weekday - DateTime.monday),
      );

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _maybeSuggest() async {
    if (!mounted) return;
    final state = context.read<MineState>();
    // Always materialize day plans so Add/Edit work on any week (incl. next).
    if (state.readySetCount < 7) {
      await state.ensureWeekSaved(_weekStart);
      return;
    }
    if (_didAutoSuggest) {
      await state.ensureWeekSaved(_weekStart);
      return;
    }
    _didAutoSuggest = true;
    await state.suggestWeekSets(
      reshuffle: state.readySetCount >= 14,
      weekStart: _weekStart,
    );
  }

  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(() {
      _weekAnchor = dateOnly(_weekAnchor.add(Duration(days: 7 * weeks)));
      _didAutoSuggest = false;
      final days = _weekDays;
      final today = dateOnly(DateTime.now());
      _focusDay = days.any((d) => sameDay(d, today)) ? today : days.first;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSuggest());
  }

  Future<void> _addLook(DayPlan day) async {
    await showWeekDayLookSheet(context, day);
  }

  /// Edit existing day look — open prefilled pieces, don't recreate via Add.
  Future<void> _editLook(DayPlan day) async {
    await showWeekEditLookSheet(context, day);
  }

  Future<void> _viewLook(DayPlan day, List<Garment> pieces) async {
    if (pieces.isEmpty) {
      await _addLook(day);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DayLookPopup(
          date: day.date,
          pieces: pieces,
          onChange: () async {
            Navigator.pop(ctx);
            await _editLook(day);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    // Materialize this visible week so every day has Add/Edit.
    state.setVisibleWeek(_weekStart);
    final weekPlan = state.ensureWeek(_weekStart);
    final days = _weekDays;
    final setCount = state.readySetCount;
    final thisMonday = mondayOf(DateTime.now());
    final isCurrentWeek = sameDay(_weekStart, thisMonday);
    final planned = days.where((d) {
      final plan = weekPlan.forDate(d);
      if (plan == null) return false;
      return state.piecesOf(plan.outfit).isNotEmpty;
    }).length;
    final range =
        '${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM').format(_weekStart.add(const Duration(days: 6)))}';
    final focus = _focusDay ?? days.first;
    final title = isCurrentWeek
        ? 'This week'
        : (_weekStart.isAfter(thisMonday) ? 'Next week' : 'Past week');

    final planner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const MineLogoMark(size: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _WeekHeroBar(
            range: range,
            planned: planned,
            total: 7,
            setCount: setCount,
            onPrev: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              setCount >= 7 ? 100 : 28,
            ),
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final date = days[index];
              final plan = weekPlan.forDate(date);
              final pieces = plan == null
                  ? const <Garment>[]
                  : state.piecesOf(plan.outfit);
              final highlighted = sameDay(date, focus);
              return _DayLookCard(
                date: date,
                plan: plan,
                pieces: pieces,
                highlighted: highlighted,
                onFocus: () => setState(() => _focusDay = date),
                onAdd: plan == null
                    ? null
                    : () => pieces.isEmpty
                        ? _addLook(plan)
                        : _editLook(plan),
                onClear:
                    plan == null ? null : () => state.clearDayOutfit(plan),
                onOpen: pieces.isEmpty || plan == null
                    ? null
                    : () => _viewLook(plan, pieces),
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) return planner;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: setCount >= 7
            ? FloatingActionButton.extended(
                onPressed: () => state.suggestWeekSets(
                  reshuffle: true,
                  weekStart: _weekStart,
                ),
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  'Suggest week',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              )
            : null,
        body: SafeArea(child: planner),
      ),
    );
  }
}

class _WeekHeroBar extends StatelessWidget {
  const _WeekHeroBar({
    required this.range,
    required this.planned,
    required this.total,
    required this.setCount,
    required this.onPrev,
    required this.onNext,
  });

  final String range;
  final int planned;
  final int total;
  final int setCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final progress = planned / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFBF7),
            Color(0xFFF7EFE6),
            Color(0xFFF3E1D4),
          ],
        ),
        border: Border.all(color: AppColors.clay.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: onPrev,
                color: AppColors.terracotta,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      range,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      setCount >= 7
                          ? '$setCount sets ready · auto-styled'
                          : (setCount > 0
                              ? '$setCount sets so far · keep building'
                              : 'Add a look to each day'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: onNext,
                color: AppColors.terracotta,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: AppColors.clay.withValues(alpha: 0.45),
                          color: AppColors.terracotta,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$planned/$total',
                  style: GoogleFonts.manrope(
                    color: AppColors.terracotta,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLookCard extends StatelessWidget {
  const _DayLookCard({
    required this.date,
    required this.plan,
    required this.pieces,
    required this.highlighted,
    required this.onFocus,
    required this.onAdd,
    required this.onClear,
    required this.onOpen,
  });

  final DateTime date;
  final DayPlan? plan;
  final List<Garment> pieces;
  final bool highlighted;
  final VoidCallback onFocus;
  final VoidCallback? onAdd;
  final VoidCallback? onClear;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(date, DateTime.now());
    final dayName = DateFormat('EEEE').format(date);
    final dayDate = DateFormat('d MMM').format(date);

    return AnimatedScale(
      scale: highlighted ? 1.0 : 0.985,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            onFocus();
            if (pieces.isEmpty) {
              onAdd?.call();
            } else {
              onOpen?.call();
            }
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.82),
              border: Border.all(
                color: highlighted || isToday
                    ? AppColors.terracotta.withValues(alpha: 0.55)
                    : AppColors.ink.withValues(alpha: 0.06),
                width: highlighted || isToday ? 1.4 : 1,
              ),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: AppColors.terracotta.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('d').format(date),
                          style: GoogleFonts.manrope(
                            fontSize: 28,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: isToday
                                ? AppColors.terracotta
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.terracottaSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TODAY',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          dayDate,
                          style: GoogleFonts.manrope(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (pieces.isEmpty)
                          Container(
                            height: 72,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.terracottaSoft
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.checkroom_outlined,
                                  color: AppColors.terracotta
                                      .withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No look yet',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.terracotta,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 78,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (var i = 0;
                                    i < pieces.length.clamp(0, 4);
                                    i++)
                                  Positioned(
                                    left: i * 36.0,
                                    child: Container(
                                      width: 68,
                                      height: 78,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.ink
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: PhotoTile(
                                          garment: pieces[i],
                                          radius: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (pieces.length > 4)
                                  Positioned(
                                    left: 4 * 36.0,
                                    top: 24,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.terracotta,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '+${pieces.length - 4}',
                                        style: GoogleFonts.manrope(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _MiniAction(
                        label: pieces.isEmpty ? 'Add' : 'Edit',
                        onTap: onAdd,
                      ),
                      if (pieces.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _MiniAction(
                          label: 'Clear',
                          muted: true,
                          onTap: onClear,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayLookPopup extends StatelessWidget {
  const _DayLookPopup({
    required this.date,
    required this.pieces,
    required this.onChange,
  });

  final DateTime date;
  final List<Garment> pieces;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE d MMM').format(date),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${pieces.length} piece${pieces.length == 1 ? '' : 's'}',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onChange,
                  child: Text(
                    'Edit',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottom),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: pieces.length,
              itemBuilder: (context, index) {
                final g = pieces[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: PhotoTile(
                          garment: g,
                          radius: 0,
                          showName: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      g.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: muted ? AppColors.muted : AppColors.terracotta,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
