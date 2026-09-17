import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'calendar_screen.dart';
import 'closet_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import '../app_nav.dart';
import '../theme/app_theme.dart';

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
      CalendarScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _DrapeNavBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _DrapeNavBar extends StatelessWidget {
  const _DrapeNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: index == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  icon: Icons.calendar_view_week_outlined,
                  selectedIcon: Icons.calendar_view_week_rounded,
                  label: 'Week',
                  selected: index == 1,
                  onTap: () => onSelect(1),
                ),
                _AddNavItem(
                  selected: index == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month_rounded,
                  label: 'Month',
                  selected: index == 3,
                  onTap: () => onSelect(3),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  selected: index == 4,
                  onTap: () => onSelect(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 38,
              child: Icon(selected ? selectedIcon : icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNavItem extends StatelessWidget {
  const _AddNavItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.terracotta,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'My Wardrobe',
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
