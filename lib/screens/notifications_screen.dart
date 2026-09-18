import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/notice.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';
import 'event_editor_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MineState>().markNoticesRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<MineState>().notificationFeed;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: const Text('Notifications'),
        ),
        body: feed.isEmpty
            ? const _EmptyNotices()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: feed.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _NoticeCard(notice: feed[index]),
              ),
      ),
    );
  }
}

class _EmptyNotices extends StatelessWidget {
  const _EmptyNotices();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: AppColors.clay,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you add clothes, save a look, or set a reminder, it will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final eventId = notice.id.startsWith('live-event-')
        ? notice.id.substring('live-event-'.length)
        : null;
    final state = context.read<MineState>();
    final event = eventId == null ? null : state.eventById(eventId);

    return Material(
      color: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: event == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventEditorScreen(existing: event),
                  ),
                ),
        leading: CircleAvatar(
          backgroundColor: AppColors.terracottaSoft,
          child: Icon(_iconFor(notice.kind), color: AppColors.terracotta),
        ),
        title: Text(
          notice.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            if (notice.body.trim().isNotEmpty) notice.body.trim(),
            DateFormat('EEE d MMM, h:mm a').format(notice.at),
          ].join(' · '),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind) {
        'clothes' => Icons.checkroom_outlined,
        'event' => Icons.event_outlined,
        'outfit' => Icons.checkroom_rounded,
        'look' => Icons.nightlife_outlined,
        'bucket' => Icons.flag_outlined,
        'import' => Icons.download_outlined,
        _ => Icons.notifications_outlined,
      };
}
