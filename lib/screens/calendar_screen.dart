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
      backgroundColor: const Color(0xFFF6F3EF),
      floatingActionButton: onWeek
          ? (setCount >= 7
              ? FloatingActionButton.extended(
                  onPressed: () => context
                      .read<MineState>()
                      .suggestWeekSets(reshuffle: true),
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Suggest week'),
                )
              : null)
          : FloatingActionButton(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              elevation: 4,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CalendarBackdropPainter()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MineLogoMark(size: 48, radius: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calendar',
                              style: GoogleFonts.manrope(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plan outfits & reminders',
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
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.terracotta,
                  indicatorWeight: 3,
                  labelColor: AppColors.ink,
                  unselectedLabelColor: AppColors.muted,
                  labelStyle: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: 'Week'),
                    Tab(text: 'Month'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      const WeekScreen(embedded: true),
                      _EventsTab(
                    month: _month,
                    selected: _selected,
                    onPrevMonth: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                    onNextMonth: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
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

class _CalendarBackdropPainter extends CustomPainter {
  const _CalendarBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF6F3EF),
    );
    final a = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x44C45C26), Color(0x00F6F3EF)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, -20),
          radius: size.width * 0.65,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, -20),
      size.width * 0.65,
      a,
    );
    final b = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x33B0894F), Color(0x00F6F3EF)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.55),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.55),
      size.width * 0.55,
      b,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2420),
                Color(0xFF3A322C),
                Color(0xFF1C1612),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.22),
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
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: const [
                  _LegendMark(
                    child: _FinishedBadge(size: 14),
                    label: 'Finished',
                    light: true,
                  ),
                  _LegendMark(
                    child: _TodayDot(),
                    label: 'Today',
                    light: true,
                  ),
                  _LegendMark(
                    child: Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: AppColors.terracotta,
                    ),
                    label: 'Reminder',
                    light: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          DateFormat('EEEE, d MMMM').format(selected),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (state.isDayCompleted(selected))
          Text(
            'Office outfit completed this day.',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              color: AppColors.terracotta,
            ),
          ),
        Builder(
          builder: (context) {
            final pieces = state.outfitPiecesFor(selected);
            if (pieces.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outfit that day',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClothesPhotoRow(
                    garments: pieces,
                    height: 110,
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
              ),
            );
          },
        ),
        if (dayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'No function, birthday or party on this day.',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
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
          child: Text(
            DateFormat('MMMM y').format(month),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
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
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
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
                    color: const Color(0xFFC4B8AE),
                    fontSize: 11,
                    letterSpacing: 0.4,
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
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 0.72,
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
    Color fill;
    Color numberColor;
    if (isToday || isSelected) {
      fill = Colors.white;
      numberColor = AppColors.ink;
    } else {
      fill = Colors.white.withValues(alpha: 0.10);
      numberColor = Colors.white;
    }

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
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: isSelected && !isToday
                        ? Border.all(
                            color: AppColors.terracotta,
                            width: 2,
                          )
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
                    child: _FinishedBadge(size: 13),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 12,
            child: hasReminder
                ? const Icon(
                    Icons.flag_rounded,
                    size: 12,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({
    required this.child,
    required this.label,
    this.light = false,
  });

  final Widget child;
  final String label;
  final bool light;

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
            color: light ? const Color(0xFFC4B8AE) : AppColors.ink,
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
      margin: const EdgeInsets.only(bottom: 10, top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.07),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventEditorScreen(existing: event)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.terracottaSoft,
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
                title: Text(
                  event.title,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${event.kind.label} · ${DateFormat('d MMM, h:mm a').format(event.at)}'
                  '${event.alarmOn ? ' · Alarm on' : ''}'
                  '${look == null ? '' : ' · ${look.name}'}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                trailing: event.alarmOn
                    ? const Icon(
                        Icons.alarm_rounded,
                        color: AppColors.terracotta,
                      )
                    : null,
              ),
              if (clothes.isNotEmpty) ...[
                const SizedBox(height: 6),
                ClothesPhotoRow(garments: clothes, height: 110),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
