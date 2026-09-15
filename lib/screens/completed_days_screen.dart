import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/settings_button.dart';
import 'day_look_screen.dart';

class CompletedDaysScreen extends StatelessWidget {
  const CompletedDaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final week = state.week;
    final workdays = week?.days
            .where((d) => state.profile.workdays.contains(d.date.weekday))
            .toList() ??
        const [];
    final history = state.completedDateList;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed'),
        actions: const [SettingsButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '${state.completedThisWeek} of ${workdays.length} days this week',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text('Completed days', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('A tick means you already wore that day’s outfit.'),
          const SizedBox(height: 18),
          if (workdays.isNotEmpty)
            Row(
              children: [
                for (final day in workdays)
                  Expanded(
                    child: _WeekDay(
                      date: day.date,
                      done: state.isDayCompleted(day.date),
                      isToday: sameDay(day.date, today),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DayLookScreen(date: day.date),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          Text('All completed days', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const EmptyState(
              title: 'No completed days yet',
              body: 'On Today, tap “I will wear this”. That day will show here.',
              icon: Icons.verified_outlined,
            )
          else
            ...history.map((date) {
              final events = state.eventsOn(date);
              final day = week?.forDate(date);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: day == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DayLookScreen(date: date),
                            ),
                          ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.sageSoft,
                    child: Icon(Icons.check_rounded, color: AppColors.sage),
                  ),
                  title: Text(
                    DateFormat('EEEE, d MMMM').format(date),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    events.isEmpty
                        ? 'Office outfit done'
                        : events.map((e) => e.title).join(', '),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.done,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool done;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? AppColors.sage
        : isToday
        ? AppColors.terracottaSoft
        : AppColors.paper;
    final fg = done ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday && !done ? AppColors.terracotta : AppColors.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E').format(date).substring(0, 1),
                style: TextStyle(fontWeight: FontWeight.w800, color: fg),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: fg,
                  fontSize: 16,
                ),
              ),
              Icon(
                done ? Icons.check_rounded : Icons.circle_outlined,
                size: 16,
                color: fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
