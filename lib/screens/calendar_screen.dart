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
import '../widgets/clothes_photo_row.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'event_editor_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _selectDay(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = dateOnly(date);
      _month = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventEditorScreen(initialDate: _selected),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  const AppBackIcon(),
                  Expanded(
                    child: Text(
                      'Your Outfit Calendar',
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
              child: _EventsTab(
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
            ),
          ],
        ),
      ),
      ),
    );
  }
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
    final state = context.watch<DrapeState>();
    final dayEvents = state.eventsOn(selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _MonthHeader(
          month: month,
          onPrev: onPrevMonth,
          onNext: onNextMonth,
        ),
        const SizedBox(height: 10),
        _MonthGrid(
          month: month,
          selected: selected,
          completedDays: state.completedDays,
          events: state.events,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            _LegendDot(color: AppColors.sage, label: 'Outfit done'),
            SizedBox(width: 14),
            _LegendDot(color: AppColors.terracotta, label: 'Event'),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          DateFormat('EEEE, d MMMM').format(selected),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (state.isDayCompleted(selected))
          const Text('Office outfit completed this day.'),
        if (dayEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No function, birthday or party on this day.',
              style: TextStyle(color: AppColors.muted),
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
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.completedDays,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Set<String> completedDays;
  final List<LifeEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final eventKeys = {for (final e in events) dateKey(e.at)};
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lead + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, i) {
            if (i < lead) return const SizedBox.shrink();
            final day = i - lead + 1;
            final date = DateTime(month.year, month.month, day);
            final key = dateKey(date);
            final isSelected = sameDay(date, selected);
            final isToday = sameDay(date, DateTime.now());
            final done = completedDays.contains(key);
            final hasEvent = eventKeys.contains(key);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.ink : AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday && !isSelected
                        ? AppColors.terracotta
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (done)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.sageSoft
                                  : AppColors.sage,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (done && hasEvent) const SizedBox(width: 3),
                        if (hasEvent)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.terracotta,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
    final state = context.watch<DrapeState>();
    final look = state.partyLookById(event.partyLookId);
    final clothes = event.garmentIds
        .map(state.garmentById)
        .whereType<Garment>()
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${event.kind.label} Â· ${DateFormat('d MMM, h:mm a').format(event.at)}'
                  '${event.alarmOn ? ' Â· Alarm on' : ''}'
                  '${look == null ? '' : ' Â· ${look.name}'}',
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
