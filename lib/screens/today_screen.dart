import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


import '../app_nav.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/common.dart';
import 'full_look_screen.dart';
import 'notifications_screen.dart';

/// Editorial home — brand first, then today's look.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final today = DateTime.now();
    final plan = state.todayPlan;
    final groups = ClothesType.todaySlots(state.profile.wearer)
        .map((type) => (type: type, items: state.optionsFor(type)))
        .where((g) => g.items.isNotEmpty)
        .toList();
    final selected = <Garment>[
      for (final g in groups)
        if (state.todaySlotGarment(g.type) case final piece?) piece,
    ];
    final canConfirm =
        plan?.outfit != null && !plan!.outfit!.isEmpty && plan.worn != true;
    final worn = plan?.worn == true;

    return _HomeStage(
      wearer: state.profile.wearer,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _rise,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 16, 0),
                  child: _HomeMasthead(
                    greeting: state.greeting,
                    weekday: DateFormat('EEEE').format(today),
                    dateLine: DateFormat('d MMMM').format(today),
                    workToday: state.isWorkToday,
                    noticeCount: state.homeNoticeCount,
                  ),
                ),
              ),
              if (groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    child: _EmptyWardrobeInvite(
                      onOpenWardrobe: () {
                        HapticFeedback.selectionClick();
                        goToShellTab?.call(2);
                      },
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                    child: _LookBoard(
                      pieces: selected,
                      worn: worn,
                      onShuffle: state.todayChoices.length > 1
                          ? () async {
                              HapticFeedback.selectionClick();
                              await state.showNextLook();
                            }
                          : null,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                    child: Text(
                      'Build the look',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 0, 0),
                  sliver: SliverList.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _SlotSection(
                          label: group.type.label,
                          garments: group.items,
                          selectedId: state.todaySlotGarment(group.type)?.id,
                          locked: plan?.locked == true || plan?.worn == true,
                          onTap: (garment) {
                            HapticFeedback.selectionClick();
                            state.selectTodaySlot(group.type, garment.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 36),
                    child: Column(
                      children: [
                        _WearCta(
                          worn: worn,
                          enabled: worn || canConfirm,
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            if (!worn) await state.acceptToday();
                            if (!context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FullLookScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          worn
                              ? 'Locked in for today'
                              : 'Tap a piece to swap it into today’s look',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bright editorial stage — light wash only, no dark overlays.
class _HomeStage extends StatelessWidget {
  const _HomeStage({required this.wearer, required this.child});

  final Wearer wearer;
  final Widget child;

  static const _lift = ColorFilter.matrix(<double>[
    1.14, 0, 0, 0, 18,
    0, 1.14, 0, 0, 18,
    0, 0, 1.12, 0, 16,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * dpr).round().clamp(1, 4096);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF6F1EA)),
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: _lift,
            child: Image.asset(
              wearer.portraitAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              isAntiAlias: true,
              gaplessPlayback: true,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.parchment),
            ),
          ),
        ),
        // Soft daylight veil — stays light top to bottom.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFF9F3).withValues(alpha: 0.88),
                  const Color(0xFFF7F0E8).withValues(alpha: 0.55),
                  const Color(0xFFF3E9DF).withValues(alpha: 0.72),
                  const Color(0xFFEFE4D8).withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.32, 0.68, 1.0],
              ),
            ),
          ),
        ),
        // Warm terracotta wash at the edge — polished, not dark.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.55),
                  radius: 1.15,
                  colors: [
                    AppColors.terracotta.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: child,
        ),
      ],
    );
  }
}

class _HomeMasthead extends StatelessWidget {
  const _HomeMasthead({
    required this.greeting,
    required this.weekday,
    required this.dateLine,
    required this.workToday,
    required this.noticeCount,
  });

  final String greeting;
  final String weekday;
  final String dateLine;
  final bool workToday;
  final int noticeCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Brand mark — logo asset, not wordmark text.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/brand/app_icon.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.terracottaSoft,
                  child: Icon(Icons.checkroom_rounded, color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                greeting,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            _NoticeBell(count: noticeCount),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          weekday,
          style: GoogleFonts.manrope(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -1.2,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              dateLine,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            if (workToday) ...[
              const SizedBox(width: 12),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Office day',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracotta,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EmptyWardrobeInvite extends StatefulWidget {
  const _EmptyWardrobeInvite({required this.onOpenWardrobe});

  final VoidCallback onOpenWardrobe;

  @override
  State<_EmptyWardrobeInvite> createState() => _EmptyWardrobeInviteState();
}

class _EmptyWardrobeInviteState extends State<_EmptyWardrobeInvite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Transform.translate(
                  offset: Offset(0, -3 + 6 * t),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/nav/wardrobe_icon.png',
                width: 78,
                height: 78,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.checkroom_rounded,
                  size: 64,
                  color: AppColors.terracotta,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your wardrobe\nis waiting',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: -0.7,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a few pieces, then dress today from here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: widget.onOpenWardrobe,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFD97845),
                      AppColors.terracotta,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.terracotta.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'Open wardrobe',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
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

class _LookBoard extends StatelessWidget {
  const _LookBoard({
    required this.pieces,
    required this.worn,
    this.onShuffle,
  });

  final List<Garment> pieces;
  final bool worn;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                worn ? 'Wearing today' : "Today’s look",
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
            if (onShuffle != null && !worn)
              GestureDetector(
                onTap: onShuffle,
                child: Row(
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      size: 18,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Shuffle',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (pieces.isEmpty)
          Text(
            'Pick pieces below to assemble today’s outfit.',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pieces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final g = pieces[i];
                final tilt = ((i % 3) - 1) * 0.03;
                return Transform.rotate(
                  angle: tilt,
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.terracotta.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: PhotoTile(garment: g, radius: 22, showName: true),
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

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.label,
    required this.garments,
    required this.selectedId,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final List<Garment> garments;
  final String? selectedId;
  final bool locked;
  final void Function(Garment garment) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.terracotta,
          ),
        ),
        const SizedBox(height: 10),
        ClothesPhotoRow(
          garments: garments,
          selectedIds: {
            if (selectedId != null) selectedId!,
          },
          onTap: locked ? null : onTap,
          height: 128,
        ),
      ],
    );
  }
}

class _WearCta extends StatelessWidget {
  const _WearCta({
    required this.worn,
    required this.enabled,
    required this.onPressed,
  });

  final bool worn;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: worn
                  ? const [Color(0xFF5F8A76), AppColors.sage]
                  : const [Color(0xFFD97845), AppColors.terracotta],
            ),
            boxShadow: [
              BoxShadow(
                color: (worn ? AppColors.sage : AppColors.terracotta)
                    .withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                worn ? Icons.check_rounded : Icons.wb_sunny_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                worn ? 'See full outfit' : 'I will wear this',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
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
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      shape: const CircleBorder(),
      shadowColor: AppColors.terracotta.withValues(alpha: 0.2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              backgroundColor: AppColors.terracotta,
              child: const Icon(
                Icons.notifications_outlined,
                size: 22,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
