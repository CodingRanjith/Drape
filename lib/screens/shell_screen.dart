import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'closet_screen.dart';
import 'completed_days_screen.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import '../app_nav.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    goToShellTab = (tab) {
      if (!mounted) return;
      setState(() => _index = tab.clamp(0, 4));
    };
  }

  @override
  void dispose() {
    goToShellTab = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      TodayScreen(),
      WeekScreen(),
      ClosetScreen(),
      CompletedDaysScreen(),
      CalendarScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week_rounded),
            label: 'Week',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom_rounded),
            label: 'Closet',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified_rounded),
            label: 'Completed',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
