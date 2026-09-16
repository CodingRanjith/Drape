import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'full_look_screen.dart';
import 'notifications_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final today = DateTime.now();
    final plan = state.todayPlan;
    final woman = state.profile.wearer == Wearer.woman;
    final groups = ClothesType.todaySlots(state.profile.wearer)
        .map((type) => (type: type, items: state.optionsFor(type)))
        .where((g) => g.items.isNotEmpty)
        .toList();

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        leading: const AppBackIcon(),
        title: const Text('Home'),
        actions: [
          _NoticeBell(count: state.homeNoticeCount),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: ProfileAvatar()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            DateFormat('EEEE').format(today),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 36),
          ),
          Text(
            DateFormat('d MMMM').format(today),
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            woman ? 'Women view' : 'Men view',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(height: 18),
          if (groups.isEmpty)
            const Text('No clothes added yet. Open Add clothes to add photos.')
          else ...[
            for (final group in groups) ...[
              Text(
                group.type.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 8),
              ClothesPhotoRow(
                garments: group.items,
                selectedIds: {
                  if (state.todaySlotGarment(group.type) != null)
                    state.todaySlotGarment(group.type)!.id,
                },
                onTap: (garment) => state.selectTodaySlot(group.type, garment.id),
              ),
              const SizedBox(height: 18),
            ],
            if (plan?.worn == true)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FullLookScreen()),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('See full outfit'),
              )
            else
              FilledButton.icon(
                onPressed: plan?.outfit == null || plan!.outfit!.isEmpty
                    ? null
                    : () async {
                        await state.acceptToday();
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FullLookScreen(),
                          ),
                        );
                      },
                icon: const Icon(Icons.check_rounded),
                label: const Text('I will wear this'),
              ),
            const SizedBox(height: 10),
            const Text(
              'Tap a photo to choose it. Open Add clothes to add more.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _NoticeBell extends StatelessWidget {
  const _NoticeBell({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.terracotta,
        child: const Icon(Icons.notifications_outlined, size: 26),
      ),
    );
  }
}
