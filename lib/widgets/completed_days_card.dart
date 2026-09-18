import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../app_nav.dart';

class CompletedDaysCard extends StatelessWidget {
  const CompletedDaysCard({super.key, this.onOpenCalendar, this.hint});

  final VoidCallback? onOpenCalendar;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final week = state.week;
    if (week == null) return const SizedBox.shrink();
    final workdays = week.days
        .where((d) => state.profile.workdays.contains(d.date.weekday))
        .toList();
    if (workdays.isEmpty) return const SizedBox.shrink();
    final done = state.completedThisWeek;
    final today = DateTime.now();

    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpenCalendar ?? () => goToShellTab?.call(3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Completed days',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '$done of ${workdays.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hint ??
                    'Open the calendar to see functions, birthdays and party wear.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final day in workdays)
                    Expanded(
                      child: _DayChip(
                        date: day.date,
                        done: state.isDayCompleted(day.date),
                        isToday: sameDay(day.date, today),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.done,
    required this.isToday,
  });

  final DateTime date;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? AppColors.sage
        : isToday
        ? AppColors.terracottaSoft
        : AppColors.parchment;
    final fg = done ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isToday && !done ? AppColors.terracotta : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('E').format(date).substring(0, 1),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: fg,
                    fontSize: 12,
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
        ],
      ),
    );
  }
}
