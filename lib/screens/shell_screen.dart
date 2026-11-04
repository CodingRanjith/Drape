import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'calendar_screen.dart';
import 'closet_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import '../app_nav.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_photo.dart';

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

    final media = MediaQuery.of(context);
    // Smile dock height + float gap; system inset lives under the dock.
    const dockClearance = 118.0;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      extendBody: true,
      body: MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(bottom: dockClearance),
          viewPadding: media.viewPadding.copyWith(bottom: dockClearance),
        ),
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: _SmileDock(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Smile / U floating dock — active orb travels the curve with bounce.
class _SmileDock extends StatefulWidget {
  const _SmileDock({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  State<_SmileDock> createState() => _SmileDockState();
}

class _SmileDockState extends State<_SmileDock>
    with TickerProviderStateMixin {
  static const _height = 112.0;
  static const _slotT = [0.04, 0.26, 0.50, 0.74, 0.96];

  late final AnimationController _travel;
  late final AnimationController _pop;
  late final Animation<double> _travelCurve;
  late final Animation<double> _popCurve;

  var _fromIndex = 0;
  var _toIndex = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.index;
    _toIndex = widget.index;
    _travel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..value = 1;
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..value = 1;
    _travelCurve = CurvedAnimation(
      parent: _travel,
      curve: Curves.easeInOutCubic,
    );
    _popCurve = CurvedAnimation(
      parent: _pop,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(covariant _SmileDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _fromIndex = oldWidget.index;
    _toIndex = widget.index;
    _travel.forward(from: 0);
    _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _travel.dispose();
    _pop.dispose();
    super.dispose();
  }

  double get _activeT {
    final a = _slotT[_fromIndex.clamp(0, 4)];
    final b = _slotT[_toIndex.clamp(0, 4)];
    return a + (b - a) * _travelCurve.value;
  }

  void _tap(int i) {
    if (i == widget.index) return;
    widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final photo = garmentImageProvider(
      context.watch<MineState>().profile.photoPath,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottom),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, _height);
            final slots = [
              for (final t in _slotT) _SmileGeometry.pointOnSmile(size, t),
            ];

            return AnimatedBuilder(
              animation: Listenable.merge([_travel, _pop]),
              builder: (context, _) {
                final orb = _SmileGeometry.pointOnSmile(size, _activeT);
                final pop = 0.86 + 0.22 * _popCurve.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sliding selection orb — follows the smile path.
                    Positioned(
                      left: orb.dx - 22,
                      top: orb.dy - 22,
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: widget.index == 2 ? 0 : pop,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.terracottaSoft,
                                  AppColors.terracotta.withValues(alpha: 0.55),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.terracotta
                                      .withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < slots.length; i++)
                      Positioned(
                        left: slots[i].dx - (i == 2 ? 31 : 24),
                        top: slots[i].dy - (i == 2 ? 31 : 24),
                        child: _SmileNavItem(
                          index: i,
                          selected: widget.index == i,
                          pop: widget.index == i ? _popCurve.value : 0,
                          photo: photo,
                          onTap: () => _tap(i),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SmileNavItem extends StatelessWidget {
  const _SmileNavItem({
    required this.index,
    required this.selected,
    required this.pop,
    required this.photo,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final double pop;
  final ImageProvider? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      final scale = selected ? 0.92 + 0.16 * pop : 1.0;
      return GestureDetector(
        onTap: onTap,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Image.asset(
              'assets/nav/wardrobe.jpg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Icon(
                Icons.checkroom_rounded,
                color: AppColors.terracotta,
                size: 36,
              ),
            ),
          ),
        ),
      );
    }

    final bounce = selected ? 0.88 + 0.20 * Curves.easeOutBack.transform(
          pop.clamp(0.0, 1.0),
        ) : 1.0;
    final lift = selected ? -6.0 * pop : 0.0;
    final color = selected ? AppColors.terracotta : AppColors.ink;
    final icon = selected ? _smileSelectedIcons[index] : _smileIcons[index];

    Widget glyph;
    if (index == 4 && photo != null) {
      glyph = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: photo!, fit: BoxFit.cover),
        ),
      );
    } else if (index == 1) {
      glyph = _WeekBars(color: color, selected: selected);
    } else {
      glyph = Icon(icon, size: 20, color: color);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: bounce,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.72),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppColors.gold.withValues(alpha: 0.28),
                ),
                boxShadow: selected
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: glyph,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final heights = selected
        ? const [10.0, 14.0, 18.0, 12.0]
        : const [9.0, 13.0, 16.0, 11.0];
    return SizedBox(
      width: 18,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights)
            Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

const _smileIcons = [
  Icons.cottage_outlined,
  Icons.view_week_outlined,
  Icons.checkroom_rounded,
  Icons.event_note_outlined,
  Icons.person_outline_rounded,
];

const _smileSelectedIcons = [
  Icons.cottage_rounded,
  Icons.view_week_rounded,
  Icons.checkroom_rounded,
  Icons.event_note_rounded,
  Icons.person_rounded,
];

class _SmileGeometry {
  static Offset pointOnSmile(Size size, double t) {
    final p0 = Offset(size.width * 0.08, size.height * 0.34);
    final p1 = Offset(size.width * 0.5, size.height * 0.92);
    final p2 = Offset(size.width * 0.92, size.height * 0.34);
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

}
