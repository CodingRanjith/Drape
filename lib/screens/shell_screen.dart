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

/// Futuristic smile dock — glass rail, traveling glow orb, bounce icons.
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
  static const _height = 118.0;
  static const _slotT = [0.04, 0.26, 0.50, 0.74, 0.96];

  late final AnimationController _travel;
  late final AnimationController _pop;
  late final AnimationController _pulse;
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
      duration: const Duration(milliseconds: 560),
    )..value = 1;
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..value = 1;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _travelCurve = CurvedAnimation(
      parent: _travel,
      curve: Curves.easeInOutCubicEmphasized,
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
    _pulse.dispose();
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
      padding: EdgeInsets.fromLTRB(10, 0, 10, 6 + bottom),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, _height);
            final slots = [
              for (final t in _slotT) _SmileGeometry.pointOnSmile(size, t),
            ];

            return AnimatedBuilder(
              animation: Listenable.merge([_travel, _pop, _pulse]),
              builder: (context, _) {
                final orb = _SmileGeometry.pointOnSmile(size, _activeT);
                final pop = 0.82 + 0.28 * _popCurve.value;
                final breath = 0.55 + 0.45 * _pulse.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Glass smile rail
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SmileRailPainter(pulse: breath),
                        ),
                      ),
                    ),
                    // Traveling energy orb
                    Positioned(
                      left: orb.dx - 28,
                      top: orb.dy - 28,
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: widget.index == 2 ? 0 : pop,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.gold.withValues(
                                          alpha: 0.22 * breath,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFFFC48A),
                                        AppColors.terracotta,
                                        const Color(0xFFE07A3D),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.terracotta
                                            .withValues(alpha: 0.45 * breath),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < slots.length; i++)
                      Positioned(
                        left: slots[i].dx - (i == 2 ? 32 : 26),
                        top: slots[i].dy - (i == 2 ? 32 : 26),
                        child: _SmileNavItem(
                          index: i,
                          selected: widget.index == i,
                          pop: widget.index == i ? _popCurve.value : 0,
                          pulse: breath,
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

class _SmileRailPainter extends CustomPainter {
  const _SmileRailPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.92,
        size.width * 0.92,
        size.height * 0.34,
      );

    // Soft glass under-glow
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
      ..color = AppColors.terracotta.withValues(alpha: 0.10 * pulse);
    canvas.drawPath(path, glow);

    // Frosted rail fill band
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 52
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawPath(path, rail);

    // Gold hairline
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gold.withValues(alpha: 0.35 + 0.2 * pulse);
    canvas.drawPath(path, line);

    // Inner bright edge
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawPath(path, inner);
  }

  @override
  bool shouldRepaint(covariant _SmileRailPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _SmileNavItem extends StatelessWidget {
  const _SmileNavItem({
    required this.index,
    required this.selected,
    required this.pop,
    required this.pulse,
    required this.photo,
    required this.onTap,
    this.onDoubleTap,
  });

  final int index;
  final bool selected;
  final double pop;
  final double pulse;
  final ImageProvider? photo;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      final scale = selected ? 0.94 + 0.14 * pop : 1.0;
      return GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.terracotta.withValues(
                    alpha: selected ? 0.28 * pulse : 0.12,
                  ),
                  blurRadius: selected ? 18 : 10,
                  spreadRadius: selected ? 1 : 0,
                ),
              ],
            ),
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

    final bounce = selected
        ? 0.86 +
            0.22 *
                Curves.easeOutBack.transform(
                  pop.clamp(0.0, 1.0),
                )
        : 1.0;
    final lift = selected ? -8.0 * pop : 0.0;
    final icon = selected ? _smileSelectedIcons[index] : _smileIcons[index];

    Widget glyph;
    if (index == 4 && photo != null) {
      glyph = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.9)
                : AppColors.gold.withValues(alpha: 0.35),
            width: 1.2,
          ),
          image: DecorationImage(image: photo!, fit: BoxFit.cover),
        ),
      );
    } else {
      glyph = Icon(
        icon,
        size: selected ? 21 : 19,
        color: selected ? Colors.white : AppColors.ink.withValues(alpha: 0.72),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: bounce,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.78),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.0)
                      : AppColors.gold.withValues(alpha: 0.22),
                ),
                boxShadow: selected
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.terracotta.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
