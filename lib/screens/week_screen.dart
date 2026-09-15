import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/outfit_look.dart';
import '../widgets/settings_button.dart';
import 'day_look_screen.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final week = state.week;
    if (week == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('This week'),
        actions: [
          const SettingsButton(),
          IconButton(
            tooltip: 'New outfits for this week',
            onPressed: () => state.refreshWeek(keepLocks: true),
            icon: const Icon(Icons.autorenew_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Week of ${DateFormat('d MMM').format(week.weekStart)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.plannedWorkdays} of ${state.workdayCount} days have an outfit',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Monday to Friday. On Today, tap the photo to see another outfit. Tap the tick if you will wear it.',
          ),
          const SizedBox(height: 18),
          if (!context.read<DrapeState>().canDressHint)
            EmptyState(
              title: 'Add a top and a pant',
              body:
                  'Add your tops and pants first. One pant can go with two or three tops. Then you will see today’s outfit.',
            )
          else
            ...week.days.map((day) => _DayCard(day: day)),
        ],
      ),
    );
  }
}

extension on DrapeState {
  bool get canDressHint {
    final clean = garments.where((g) => !g.inLaundry);
    return clean.any(
      (g) =>
          g.category == GarmentCategory.dress ||
          g.category == GarmentCategory.top ||
          g.category == GarmentCategory.bottom,
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});
  final DayPlan day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final isWork = state.profile.workdays.contains(day.date.weekday);
    final isToday = sameDay(day.date, DateTime.now());
    final pieces = state.piecesOf(day.outfit);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isToday ? AppColors.ink : AppColors.line,
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isWork
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DayLookScreen(date: day.date)),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE').format(day.date).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 12,
                        color: AppColors.terracotta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d MMM').format(day.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      const _Pill('Today', AppColors.ink, Colors.white),
                    ],
                    if (day.worn) ...[
                      const SizedBox(width: 8),
                      const _Pill('Worn', AppColors.sage, Colors.white),
                    ],
                    const Spacer(),
                    if (isWork)
                      IconButton(
                        tooltip: day.locked ? 'Unlock' : 'Keep this outfit',
                        onPressed: () => state.toggleLock(day),
                        icon: Icon(
                          day.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: day.locked ? AppColors.terracotta : AppColors.muted,
                        ),
                      ),
                  ],
                ),
                if (!isWork)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text('Off day. No office outfit today.'),
                  )
                else if (pieces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text('No outfit yet. Tap to choose one.'),
                  )
                else
                  OutfitLook(pieces: pieces, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
