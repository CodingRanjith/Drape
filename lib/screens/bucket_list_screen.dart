import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/bucket_list.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;
  late final AnimationController _sparkCtrl;
  bool _burst = false;
  Offset _burstAt = Offset.zero;

  static const _sparks = [
    'Wear all-white for one day',
    'Try a color you never wear',
    'Build a rainy-day outfit',
    'Dress up for a coffee run',
    'Mix two eras in one look',
    'Find the perfect travel shoes',
    'Recreate a Pinterest fit',
    'Wear your boldest piece out',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _burst = false);
          _sparkCtrl.reset();
        }
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  Future<void> _celebrate(Offset global) async {
    final box = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(global) ??
        Offset(MediaQuery.sizeOf(context).width / 2, 180);
    setState(() {
      _burst = true;
      _burstAt = local;
    });
    HapticFeedback.heavyImpact();
    await _sparkCtrl.forward(from: 0);
  }

  Future<void> _openEditor({StyleBucketItem? existing}) async {
    final result = await showModalBottomSheet<_BucketDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) => _BucketEditorSheet(existing: existing),
    );
    if (!mounted || result == null) return;
    final state = context.read<DrapeState>();
    final isExisting = existing != null && existing.id != 'draft';
    if (!isExisting) {
      await state.addBucketItem(
        title: result.title,
        note: result.note,
        vibe: result.vibe,
      );
      HapticFeedback.lightImpact();
    } else {
      await state.updateBucketItem(
        existing.id,
        title: result.title,
        note: result.note,
        vibe: result.vibe,
      );
    }
  }

  Future<void> _complete(StyleBucketItem item, Offset global) async {
    await context.read<DrapeState>().completeBucketItem(item.id);
    if (!mounted) return;
    await _celebrate(global);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(
          'Quest complete · ${item.title}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.terracottaSoft,
          onPressed: () => context.read<DrapeState>().reopenBucketItem(item.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final open = state.openBucketItems;
    final done = state.completedBucketItems;
    final total = state.bucketList.length;
    final progress = state.bucketProgress;

    return PageBackground(
      overlayColor: const Color(0xF0F7F7F7),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New dream'),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                    child: Row(
                      children: [
                        const AppBackIcon(),
                        Expanded(
                          child: Text(
                            'Style Bucketlist',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _QuestHero(
                      openCount: open.length,
                      doneCount: done.length,
                      progress: progress,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SparkStrip(
                      sparks: _sparks,
                      onTapSpark: (text) => _openEditor(
                        existing: StyleBucketItem(id: 'draft', title: text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.muted,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(text: 'Created · ${open.length}'),
                          Tab(text: 'Completed · ${done.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _BucketListPane(
                          items: open,
                          emptyTitle: total == 0
                              ? 'Your style quests start here'
                              : 'No open dreams',
                          emptyBody: total == 0
                              ? 'Add a fashion wish, tap spark ideas, then chase the look.'
                              : 'Everything on your list is already celebrated.',
                          onAdd: () => _openEditor(),
                          onEdit: (item) => _openEditor(existing: item),
                          onStar: (item) =>
                              context.read<DrapeState>().toggleBucketStar(item.id),
                          onPrimary: (item, offset) => _complete(item, offset),
                          primaryLabel: 'Done',
                          primaryIcon: Icons.check_rounded,
                        ),
                        _BucketListPane(
                          items: done,
                          emptyTitle: 'No wins yet',
                          emptyBody:
                              'Complete a created dream and it will shine here.',
                          onAdd: () => _tabs.animateTo(0),
                          onEdit: (item) => _openEditor(existing: item),
                          onStar: (item) =>
                              context.read<DrapeState>().toggleBucketStar(item.id),
                          onPrimary: (item, _) async {
                            await context
                                .read<DrapeState>()
                                .reopenBucketItem(item.id);
                            HapticFeedback.selectionClick();
                          },
                          primaryLabel: 'Reopen',
                          primaryIcon: Icons.replay_rounded,
                          completedStyle: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_burst)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SparkBurstPainter(
                      progress: _sparkCtrl,
                      origin: _burstAt,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestHero extends StatelessWidget {
  const _QuestHero({
    required this.openCount,
    required this.doneCount,
    required this.progress,
  });

  final int openCount;
  final int doneCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A221C), Color(0xFF3F5E51), Color(0xFFC45C26)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CustomPaint(
                    painter: _RingPainter(value),
                    child: Center(
                      child: Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fashion quest board',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    openCount == 0 && doneCount == 0
                        ? 'Collect looks you want to live.'
                        : '$openCount chasing · $doneCount celebrated',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatPill(icon: Icons.flag_rounded, label: '$openCount open'),
                      _StatPill(
                        icon: Icons.emoji_events_outlined,
                        label: '$doneCount done',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkStrip extends StatelessWidget {
  const _SparkStrip({required this.sparks, required this.onTapSpark});

  final List<String> sparks;
  final ValueChanged<String> onTapSpark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spark ideas',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sparks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final text = sparks[i];
              return ActionChip(
                onPressed: () => onTapSpark(text),
                backgroundColor: AppColors.paper,
                side: const BorderSide(color: AppColors.line),
                avatar: Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: AppColors.terracotta.withValues(alpha: 0.9),
                ),
                label: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.ink,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BucketListPane extends StatelessWidget {
  const _BucketListPane({
    required this.items,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onAdd,
    required this.onEdit,
    required this.onStar,
    required this.onPrimary,
    required this.primaryLabel,
    required this.primaryIcon,
    this.completedStyle = false,
  });

  final List<StyleBucketItem> items;
  final String emptyTitle;
  final String emptyBody;
  final VoidCallback onAdd;
  final ValueChanged<StyleBucketItem> onEdit;
  final ValueChanged<StyleBucketItem> onStar;
  final void Function(StyleBucketItem item, Offset global) onPrimary;
  final String primaryLabel;
  final IconData primaryIcon;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.terracottaSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completedStyle
                      ? Icons.emoji_events_outlined
                      : Icons.auto_awesome_rounded,
                  size: 38,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptyBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAdd,
                child: Text(completedStyle ? 'Browse created' : 'Add first dream'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + (index * 40).clamp(0, 240)),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 16),
                child: child,
              ),
            );
          },
          child: _BucketCard(
            item: item,
            completedStyle: completedStyle,
            onEdit: () => onEdit(item),
            onStar: () => onStar(item),
            onPrimary: (offset) => onPrimary(item, offset),
            primaryLabel: primaryLabel,
            primaryIcon: primaryIcon,
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete this dream?'),
                  content: Text(item.title),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<DrapeState>().deleteBucketItem(item.id);
              }
            },
          ),
        );
      },
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.item,
    required this.completedStyle,
    required this.onEdit,
    required this.onStar,
    required this.onPrimary,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onDelete,
  });

  final StyleBucketItem item;
  final bool completedStyle;
  final VoidCallback onEdit;
  final VoidCallback onStar;
  final ValueChanged<Offset> onPrimary;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = completedStyle
        ? item.completedAt ?? item.createdAt
        : item.createdAt;
    final dateLabel = completedStyle
        ? 'Celebrated ${DateFormat('d MMM').format(date)}'
        : 'Pinned ${DateFormat('d MMM').format(date)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xF7FFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: item.starred
                    ? item.vibe.accent.withValues(alpha: 0.45)
                    : AppColors.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.vibe.soft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.vibe.icon, color: item.vibe.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.vibe.soft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item.vibe.label,
                                      style: TextStyle(
                                        color: item.vibe.accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                if (item.starred) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: AppColors.gold,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.ink,
                                decoration: completedStyle
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor:
                                    AppColors.muted.withValues(alpha: 0.7),
                              ),
                            ),
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: item.starred ? 'Unstar' : 'Star',
                        onPressed: onStar,
                        icon: Icon(
                          item.starred
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: item.starred ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onEdit,
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                        ),
                        child: const Text('Delete'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          final box =
                              context.findRenderObject() as RenderBox?;
                          final offset = box?.localToGlobal(
                                box.size.center(Offset.zero),
                              ) ??
                              Offset.zero;
                          onPrimary(offset);
                        },
                        icon: Icon(primaryIcon, size: 18),
                        label: Text(primaryLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: completedStyle
                              ? AppColors.sage
                              : item.vibe.accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BucketDraft {
  const _BucketDraft({
    required this.title,
    required this.note,
    required this.vibe,
  });

  final String title;
  final String note;
  final BucketVibe vibe;
}

class _BucketEditorSheet extends StatefulWidget {
  const _BucketEditorSheet({this.existing});

  final StyleBucketItem? existing;

  @override
  State<_BucketEditorSheet> createState() => _BucketEditorSheetState();
}

class _BucketEditorSheetState extends State<_BucketEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late BucketVibe _vibe;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _vibe = existing?.vibe ?? BucketVibe.styleChallenge;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _BucketDraft(title: title, note: _note.text.trim(), vibe: _vibe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null && widget.existing!.id != 'draft';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit style dream' : 'New style dream',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick a vibe, write the look you want to chase, then go make it real.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Dream title',
                hintText: 'e.g. Monochrome coffee-date fit',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Colors, pieces, or the feeling you want',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vibe',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final vibe in BucketVibe.values)
                  ChoiceChip(
                    selected: _vibe == vibe,
                    onSelected: (_) => setState(() => _vibe = vibe),
                    avatar: Icon(
                      vibe.icon,
                      size: 16,
                      color: _vibe == vibe ? Colors.white : vibe.accent,
                    ),
                    label: Text(vibe.label),
                    selectedColor: vibe.accent,
                    labelStyle: TextStyle(
                      color: _vibe == vibe ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: _vibe == vibe ? vibe.accent : AppColors.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _vibe.hint,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save dream' : 'Add to bucketlist'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFFF3E1D4), Color(0xFFC45C26), Color(0xFFDCE6E0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _SparkBurstPainter extends CustomPainter {
  _SparkBurstPainter({required this.progress, required this.origin})
      : super(repaint: progress);

  final Animation<double> progress;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(progress.value);
    final paint = Paint()..style = PaintingStyle.fill;
    const colors = [
      Color(0xFFC45C26),
      Color(0xFFB0894F),
      Color(0xFFDCE6E0),
      Color(0xFFF3E1D4),
      Color(0xFF6B2748),
    ];
    for (var i = 0; i < 18; i++) {
      final angle = (i / 18) * math.pi * 2;
      final dist = 28 + (i % 5) * 18.0;
      final p = origin + Offset(math.cos(angle), math.sin(angle)) * dist * t;
      paint.color = colors[i % colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(p, 4.5 * (1 - t * 0.55), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) =>
      oldDelegate.origin != origin || oldDelegate.progress != progress;
}
