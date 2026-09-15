import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';
import '../widgets/settings_button.dart';
import 'event_editor_screen.dart';
import 'party_wear_editor_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final dayEvents = state.eventsOn(_selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: const [SettingsButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventEditorScreen(initialDate: _selected),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _MonthHeader(
            month: _month,
            onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          ),
          const SizedBox(height: 10),
          _MonthGrid(
            month: _month,
            selected: _selected,
            completedDays: state.completedDays,
            events: state.events,
            onSelect: (d) => setState(() => _selected = d),
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
            DateFormat('EEEE, d MMMM').format(_selected),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (state.isDayCompleted(_selected))
            const Text('Office outfit completed this day.'),
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No function, birthday or party on this day.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...dayEvents.map((e) => _EventTile(event: e)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Party wear',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PartyWearEditorScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Upload'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Upload photos of function and party clothes. You can attach them to a date.'),
          const SizedBox(height: 12),
          if (state.partyLooks.isEmpty)
            EmptyState(
              title: 'No party wear yet',
              body: 'Add a photo of what you wear for functions, weddings and parties.',
              actionLabel: 'Upload party wear',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PartyWearEditorScreen()),
              ),
              icon: Icons.celebration_outlined,
            )
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.partyLooks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final look = state.partyLooks[i];
                  final photo = garmentImageProvider(look.imagePath);
                  return SizedBox(
                    width: 118,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PartyWearEditorScreen(existing: look),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: photo == null
                                  ? const ColoredBox(
                                      color: AppColors.clay,
                                      child: Center(child: Icon(Icons.checkroom_outlined)),
                                    )
                                  : Image(image: photo, fit: BoxFit.cover, width: double.infinity),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            look.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            look.occasion.label,
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          Text('Coming up', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (state.upcomingEvents.isEmpty)
            const Text('No upcoming birthday, function or party yet.')
          else
            ...state.upcomingEvents.map((e) => _EventTile(event: e)),
        ],
      ),
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
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
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
                    color: isToday && !isSelected ? AppColors.terracotta : Colors.transparent,
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
                              color: isSelected ? AppColors.sageSoft : AppColors.sage,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (done && hasEvent) const SizedBox(width: 3),
                        if (hasEvent)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.gold : AppColors.terracotta,
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${event.kind.label} · ${DateFormat('d MMM, h:mm a').format(event.at)}'
                  '${event.alarmOn ? ' · Alarm on' : ''}'
                  '${look == null ? '' : ' · ${look.name}'}',
                ),
                trailing: event.alarmOn
                    ? const Icon(Icons.alarm_rounded, color: AppColors.terracotta)
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
