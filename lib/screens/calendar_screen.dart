import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/mine_logo_mark.dart';
import 'event_editor_screen.dart';
import 'outfit_full_view_screen.dart';
import 'week_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _month;
  DateTime _selected = DateTime.now();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging || !mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _selectDay(DateTime date) {
    HapticFeedback.selectionClick();
    final day = dateOnly(date);
    setState(() {
      _selected = day;
      _month = DateTime(date.year, date.month);
    });
    final pieces = context.read<MineState>().outfitPiecesFor(day);
    if (pieces.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OutfitFullViewScreen(pieces: pieces, date: day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onWeek = _tabs.index == 0;
    final setCount = context.watch<MineState>().readySetCount;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EC),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: onWeek
            ? (setCount >= 7
                ? FloatingActionButton.extended(
                    key: const ValueKey('suggest'),
                    onPressed: () {
                      final state = context.read<MineState>();
                      state.suggestWeekSets(
                        reshuffle: true,
                        weekStart: state.visibleWeekStart,
                      );
                    },
                    backgroundColor: AppColors.terracotta,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(
                      'Suggest week',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')))
            : FloatingActionButton(
                key: const ValueKey('add-event'),
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventEditorScreen(initialDate: _selected),
                  ),
                ),
                child: const Icon(Icons.add_rounded),
              ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CalendarBackdropPainter()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const MineLogoMark(size: 46, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calendar',
                              style: GoogleFonts.manrope(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                                height: 1.05,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              onWeek
                                  ? 'Style every day of the week'
                                  : 'Outfits, events & reminders',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SegmentTabs(
                    index: _tabs.index,
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      _tabs.animateTo(i);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      const WeekScreen(embedded: true),
                      _MonthTab(
                        month: _month,
                        selected: _selected,
                        onPrevMonth: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                        onNextMonth: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                        onSelect: _selectDay,
                      ),
                    ],
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

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.clay.withValues(alpha: 0.55)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 0) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment:
                    index == 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: w,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.terracotta.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SegLabel(
                      label: 'Week',
                      selected: index == 0,
                      onTap: () => onChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _SegLabel(
                      label: 'Month',
                      selected: index == 1,
                      onTap: () => onChanged(1),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: -0.2,
            color: selected ? Colors.white : AppColors.muted,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _CalendarBackdropPainter extends CustomPainter {
  const _CalendarBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F1EC),
    );
    final a = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x38C45C26), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.92, -40),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.92, -40),
      size.width * 0.7,
      a,
    );
    final b = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x28B0894F), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(-20, size.height * 0.42),
          radius: size.width * 0.58,
        ),
      );
    canvas.drawCircle(
      Offset(-20, size.height * 0.42),
      size.width * 0.58,
      b,
    );
    final c = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x1A3F5E51), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.55, size.height * 0.95),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.95),
      size.width * 0.5,
      c,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonthTab extends StatelessWidget {
  const _MonthTab({
    required this.month,
    required this.selected,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final dayEvents = state.eventsOn(selected);
    final pieces = state.outfitPiecesFor(selected);
    final completed = state.isDayCompleted(selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
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
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              _MonthHeader(
                month: month,
                onPrev: onPrevMonth,
                onNext: onNextMonth,
              ),
              const SizedBox(height: 14),
              _MonthGrid(
                month: month,
                selected: selected,
                events: state.events,
                onSelect: onSelect,
              ),
              const SizedBox(height: 14),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _LegendMark(
                    label: 'Past',
                    child: _FinishedBadge(size: 14),
                  ),
                  _LegendMark(
                    label: 'Today',
                    child: _TodayDot(),
                  ),
                  _LegendMark(
                    label: 'Event',
                    child: Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(selected),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.terracotta,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMMM').format(selected),
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (completed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.terracottaSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Worn',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
          ],
        ),
        if (pieces.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Outfit',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          ClothesPhotoRow(
            garments: pieces,
            height: 118,
            onTap: (g) {
              final i = pieces.indexOf(g);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OutfitFullViewScreen(
                    pieces: pieces,
                    date: selected,
                    initialIndex: i < 0 ? 0 : i,
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Events',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (dayEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: AppColors.muted.withValues(alpha: 0.7),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing planned',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to add a birthday, party or function.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          )
        else
          ...dayEvents.map((e) => _EventTile(event: e)),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavChip(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Expanded(
          child: Column(
            children: [
              Text(
                DateFormat('MMMM').format(month),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
              Text(
                DateFormat('y').format(month),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        _NavChip(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.terracottaSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.terracotta),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<LifeEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final eventKeys = {for (final e in events) dateKey(e.at)};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lead + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox.shrink();
            final day = i - lead + 1;
            final date = DateTime(month.year, month.month, day);
            final key = dateKey(date);
            final isSelected = sameDay(date, selected);
            final isToday = sameDay(date, today);
            final finished = date.isBefore(today);
            final hasEvent = eventKeys.contains(key);
            return _DayCell(
              day: day,
              isSelected: isSelected,
              isToday: isToday,
              completed: finished,
              hasReminder: hasEvent,
              onTap: () => onSelect(date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.completed,
    required this.hasReminder,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool completed;
  final bool hasReminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = isToday
        ? AppColors.terracotta
        : (isSelected ? AppColors.terracottaSoft : Colors.white);
    final numberColor = isToday
        ? Colors.white
        : (isSelected ? AppColors.terracotta : AppColors.ink);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: isToday
                        ? null
                        : Border.all(
                            color: isSelected
                                ? AppColors.terracotta
                                : AppColors.clay.withValues(alpha: 0.55),
                            width: isSelected ? 1.5 : 1,
                          ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: AppColors.terracotta.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: numberColor,
                      height: 1,
                    ),
                  ),
                ),
                if (completed && !isToday)
                  const Positioned(
                    top: -1,
                    child: _FinishedBadge(size: 12),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 12,
            child: hasReminder
                ? const Icon(
                    Icons.flag_rounded,
                    size: 11,
                    color: AppColors.terracotta,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge({this.size = 13});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE24C43),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check_rounded, size: size * 0.72, color: Colors.white),
    );
  }
}

class _TodayDot extends StatelessWidget {
  const _TodayDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({
    required this.child,
    required this.label,
  });

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final LifeEvent event;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final look = state.partyLookById(event.partyLookId);
    final clothes = event.garmentIds
        .map(state.garmentById)
        .whereType<Garment>()
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventEditorScreen(existing: event)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.terracottaSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      switch (event.kind) {
                        EventKind.birthday => Icons.cake_outlined,
                        EventKind.function => Icons.apartment_outlined,
                        EventKind.party => Icons.celebration_outlined,
                        EventKind.other => Icons.event_outlined,
                      },
                      color: AppColors.terracotta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.kind.label} · ${DateFormat('d MMM, h:mm a').format(event.at)}'
                          '${event.alarmOn ? ' · Alarm' : ''}'
                          '${look == null ? '' : ' · ${look.name}'}',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (event.alarmOn)
                    const Icon(
                      Icons.alarm_rounded,
                      color: AppColors.terracotta,
                      size: 20,
                    ),
                ],
              ),
              if (clothes.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClothesPhotoRow(garments: clothes, height: 100),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
