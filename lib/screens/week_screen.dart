import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/page_background.dart';
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
    if (state.readySetCount < 7) return;
    _didAutoSuggest = true;
    await state.suggestWeekSets(reshuffle: state.readySetCount >= 14);
  }

  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(() {
      _weekAnchor = dateOnly(_weekAnchor.add(Duration(days: 7 * weeks)));
      _didAutoSuggest = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSuggest());
  }

  Future<void> _addLook(DayPlan day) async {
    if (day.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock this day before changing the look.')),
      );
      return;
    }
    final state = context.read<DrapeState>();
    final sets = state.availableSetsForDay(day);
    final dresses = state.availableDressesForDay(day);
    if (sets.isEmpty && dresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No free sets or dresses left. Add more in My outfit, or unlock other days.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add set or dress',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Sets'),
                      Tab(text: 'Dresses'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _LookPickList(
                          emptyLabel: 'No sets available for this day.',
                          itemCount: sets.length,
                          itemBuilder: (context, index) {
                            final set = sets[index];
                            final pieces = state.piecesOf(set.outfit);
                            return ListTile(
                              leading: SizedBox(
                                width: 48,
                                height: 48,
                                child: pieces.isEmpty
                                    ? const Icon(Icons.layers_outlined)
                                    : PhotoTile(
                                        garment: pieces.first,
                                        radius: 12,
                                      ),
                              ),
                              title: Text(set.name),
                              subtitle: Text(
                                '${set.collection.label} · ${pieces.length} pieces',
                              ),
                              onTap: () async {
                                final messenger =
                                    ScaffoldMessenger.of(this.context);
                                final ok =
                                    await state.assignSetToDay(day, set);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                if (!ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'That set uses items already planned this week.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        _LookPickList(
                          emptyLabel: 'No dresses available for this day.',
                          itemCount: dresses.length,
                          itemBuilder: (context, index) {
                            final dress = dresses[index];
                            return ListTile(
                              leading: SizedBox(
                                width: 48,
                                height: 48,
                                child: PhotoTile(garment: dress, radius: 12),
                              ),
                              title: Text(
                                dress.name.isEmpty ? 'Dress' : dress.name,
                              ),
                              subtitle: Text(dress.shelfLabel),
                              onTap: () async {
                                final messenger =
                                    ScaffoldMessenger.of(this.context);
                                final ok =
                                    await state.assignDressToDay(day, dress);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                if (!ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'That dress is already planned this week.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final days = _weekDays;
    final setCount = state.readySetCount;
    final range =
        '${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM').format(_weekStart.add(const Duration(days: 6)))}';

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: setCount >= 7
            ? FloatingActionButton.extended(
                onPressed: () => state.suggestWeekSets(reshuffle: true),
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Suggest week'),
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
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
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: () => _shiftWeek(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: () => _shiftWeek(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  setCount >= 7
                      ? '$range · $setCount sets ready · auto-suggested'
                      : '$range · Add a set or dress on each day'
                          '${setCount > 0 ? ' · $setCount sets so far' : ''}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    setCount >= 7 ? 96 : 24,
                  ),
                  itemCount: 7,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final date = days[index];
                    final plan = state.week?.forDate(date);
                    final pieces = plan == null
                        ? const <Garment>[]
                        : state.piecesOf(plan.outfit);
                    return _DayCard(
                      date: date,
                      plan: plan,
                      pieces: pieces,
                      onAdd: plan == null ? null : () => _addLook(plan),
                      onLock: plan == null
                          ? null
                          : () => state.toggleLock(plan),
                      onClear: plan == null || plan.locked
                          ? null
                          : () => state.clearDayOutfit(plan),
                      onOpen: pieces.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OutfitFullViewScreen(
                                    pieces: pieces,
                                    date: date,
                                  ),
                                ),
                              ),
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

class _LookPickList extends StatelessWidget {
  const _LookPickList({
    required this.emptyLabel,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String emptyLabel;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.plan,
    required this.pieces,
    required this.onAdd,
    required this.onLock,
    required this.onClear,
    required this.onOpen,
  });

  final DateTime date;
  final DayPlan? plan;
  final List<Garment> pieces;
  final VoidCallback? onAdd;
  final VoidCallback? onLock;
  final VoidCallback? onClear;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final locked = plan?.locked ?? false;
    final isToday = sameDay(date, DateTime.now());
    final dayName = DateFormat('EEEE').format(date);
    final dayDate = DateFormat('d MMM').format(date);

    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isToday ? AppColors.terracotta : AppColors.line,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: pieces.isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.terracottaSoft.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.checkroom_outlined,
                            color: AppColors.terracotta,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: PhotoTile(garment: pieces.first, radius: 0),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dayName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (locked)
                            const Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: AppColors.terracotta,
                            ),
                        ],
                      ),
                      Text(
                        dayDate,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pieces.isEmpty
                            ? 'No look yet'
                            : '${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}',
                        style: TextStyle(
                          color: pieces.isEmpty
                              ? AppColors.muted
                              : AppColors.sage,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (pieces.length > 1) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: pieces.length.clamp(0, 4),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 4),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: 28,
                                height: 28,
                                child: PhotoTile(
                                  garment: pieces[index],
                                  radius: 8,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: locked ? 'Unlock' : 'Lock',
                      onPressed: onLock,
                      icon: Icon(
                        locked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: locked
                            ? AppColors.terracotta
                            : AppColors.muted,
                      ),
                    ),
                    if (!locked)
                      TextButton(
                        onPressed: onAdd,
                        child: const Text('Add'),
                      ),
                    if (!locked && pieces.isNotEmpty)
                      TextButton(
                        onPressed: onClear,
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 12),
                        ),
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
