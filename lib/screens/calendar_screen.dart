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
import '../widgets/clothes_photo_row.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'day_look_screen.dart';
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
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  List<DateTime> get _weekDays {
    final start = dateOnly(_selected).subtract(
      Duration(days: _selected.weekday - DateTime.monday),
    );
    return List.generate(7, (i) => start.add(Duration(days: i)));
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
      _month = DateTime(picked.year, picked.month);
    });
  }

  void _selectDay(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = dateOnly(date);
      _month = DateTime(date.year, date.month);
    });
  }

  void _openWardrobe() => goToShellTab?.call(2);

  Future<void> _addLook() async {
    final state = context.read<DrapeState>();
    if (state.garments.isEmpty && state.partyLooks.isEmpty) {
      _openWardrobe();
      return;
    }
    final plan = state.week?.forDate(_selected);
    if (plan != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayLookScreen(date: _selected)),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(initialDate: _selected),
      ),
    );
  }

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
      return;
    }
    await _addLook();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();

    return PageBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventEditorScreen(initialDate: _selected),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            )
          : null,
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Segmented(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tab == 0
                  ? _OutfitsTab(
                      selected: _selected,
                      weekDays: _weekDays,
                      onPickDate: _pickDate,
                      onSelectDay: _selectDay,
                      onAdd: _addLook,
                      onOpenLook: () => _openLook(state),
                      onWardrobe: _openWardrobe,
                    )
                  : _EventsTab(
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

class _OutfitsTab extends StatelessWidget {
  const _OutfitsTab({
    required this.selected,
    required this.weekDays,
    required this.onPickDate,
    required this.onSelectDay,
    required this.onAdd,
    required this.onOpenLook,
    required this.onWardrobe,
  });

  final DateTime selected;
  final List<DateTime> weekDays;
  final VoidCallback onPickDate;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onAdd;
  final VoidCallback onOpenLook;
  final VoidCallback onWardrobe;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final look = _LookData.resolve(state, selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                DateFormat('EEEE').format(selected),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onPickDate,
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
                    onAdd: onAdd,
                    onOpen: onOpenLook,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final day in weekDays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DateChip(
                      date: day,
                      selected: sameDay(day, selected),
                      marked: _LookData.resolve(state, day).hasVisual,
                      onTap: () => onSelectDay(day),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWardrobe,
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
    required this.onAdd,
    required this.onOpen,
  });

  final _LookData look;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3EEE8),
      elevation: 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(44),
      child: InkWell(
        onTap: look.hasVisual ? onOpen : onAdd,
        borderRadius: BorderRadius.circular(44),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEE8),
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
                : _AddLookButton(onAdd: onAdd),
          ),
        ),
      ),
    );
  }
}

class _AddLookButton extends StatelessWidget {
  const _AddLookButton({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: const SizedBox(
              width: 84,
              height: 84,
              child: Icon(
                Icons.add_rounded,
                size: 38,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 36,
          child: Text(
            'Add look',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
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

class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE6DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _SegChip(
            label: 'Outfits',
            selected: index == 0,
            onTap: () => onChanged(0),
          ),
          _SegChip(
            label: 'Events',
            selected: index == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.muted,
            ),
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
                MaterialPageRoute(
                  builder: (_) => const PartyWearEditorScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload photos of function and party clothes. You can attach them to a date.',
        ),
        const SizedBox(height: 12),
        if (state.partyLooks.isEmpty)
          EmptyState(
            title: 'No party wear yet',
            body:
                'Add a photo of what you wear for functions, weddings and parties.',
            actionLabel: 'Upload party wear',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PartyWearEditorScreen(),
              ),
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
                                    child: Center(
                                      child: Icon(Icons.checkroom_outlined),
                                    ),
                                  )
                                : Image(
                                    image: photo,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
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
                  '${event.kind.label} · ${DateFormat('d MMM, h:mm a').format(event.at)}'
                  '${event.alarmOn ? ' · Alarm on' : ''}'
                  '${look == null ? '' : ' · ${look.name}'}',
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
