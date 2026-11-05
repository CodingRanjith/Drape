import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'calendar_screen.dart';
import 'ecommerce_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'wardrobe_chamber_screen.dart';
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
  /// Bumped when opening wardrobe tab so doors always start closed.
  var _wardrobeSession = 0;

  void _selectTab(int i) {
    setState(() {
      // Fresh wardrobe visit starts closed; stay put if already on this tab.
      if (i == 2 && _index != 2) _wardrobeSession++;
      _index = i.clamp(0, 4);
    });
  }

  void _onWardrobeDoubleTap() {
    if (_index != 2) {
      _selectTab(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // New session is closed — open on double-tap arrive.
        toggleWardrobeDoors?.call();
      });
      return;
    }
    toggleWardrobeDoors?.call();
  }

  @override
  void initState() {
    super.initState();
    goToShellTab = (tab) {
      if (!mounted) return;
      _selectTab(tab);
    };
  }

  @override
  void dispose() {
    goToShellTab = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TodayScreen(),
      const EcommerceScreen(),
      WardrobeChamberScreen(key: ValueKey(_wardrobeSession)),
      const CalendarScreen(),
      const SettingsScreen(),
    ];

    final media = MediaQuery.of(context);
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
        onSelect: _selectTab,
        onWardrobeDoubleTap: _onWardrobeDoubleTap,
      ),
    );
  }
}

/// Smile / U floating dock — active orb travels the curve with bounce.
class _SmileDock extends StatefulWidget {
  const _SmileDock({
    required this.index,
    required this.onSelect,
    required this.onWardrobeDoubleTap,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onWardrobeDoubleTap;

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
                          onDoubleTap:
                              i == 2 ? widget.onWardrobeDoubleTap : null,
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
    this.onDoubleTap,
  });

  final int index;
  final bool selected;
  final double pop;
  final ImageProvider? photo;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      final scale = selected ? 0.92 + 0.16 * pop : 1.0;
      return GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/nav/wardrobe_icon.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Icon(
                Icons.checkroom_rounded,
                color: AppColors.terracotta,
                size: 28,
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

const _smileIcons = [
  Icons.cottage_outlined,
  Icons.shopping_bag_outlined,
  Icons.checkroom_rounded,
  Icons.event_note_outlined,
  Icons.person_outline_rounded,
];

const _smileSelectedIcons = [
  Icons.cottage_rounded,
  Icons.shopping_bag_rounded,
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
