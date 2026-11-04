import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_nav.dart';
import '../models/wardrobe.dart';
import '../services/wardrobe_locker.dart';
import '../state/mine_state.dart';
import '../widgets/add_item_form_dialog.dart';
import '../widgets/common.dart';
import '../widgets/mine_logo_mark.dart';
import 'add_clothes_screen.dart';
import 'bucket_list_screen.dart';
import 'garment_detail_screen.dart';

/// Drawn wardrobe (no photo): tap once to open doors, shelves with items.
/// Lives under the bottom nav as a normal shell tab.
class WardrobeChamberScreen extends StatefulWidget {
  const WardrobeChamberScreen({super.key});

  @override
  State<WardrobeChamberScreen> createState() => _WardrobeChamberScreenState();
}

class _WardrobeChamberScreenState extends State<WardrobeChamberScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _knock;
  late final AnimationController _doors;
  late final AnimationController _interior;

  late final Animation<double> _enterFade;
  late final Animation<double> _knockShake;
  late final Animation<double> _leftDoor;
  late final Animation<double> _rightDoor;
  late final Animation<double> _doorOpen;
  late final Animation<double> _interiorFade;

  var _isOpen = false;
  var _isLocked = false;
  var _hasPin = false;
  var _lockerReady = false;
  /// Left Locker tapped — center padlock visible until PIN finishes or cancel.
  var _lockerArmed = false;

  /// Slow push → swing → soft settle (real hinge weight).
  static const _hingeCurve = Cubic(0.22, 0.61, 0.28, 1.0);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _knock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _doors = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1480),
    );
    _interior = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _enterFade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _knockShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -1.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -1.1, end: 1.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _knock, curve: Curves.easeOut));

    // Left leads slightly; right follows — natural two-door stagger.
    _leftDoor = CurvedAnimation(
      parent: _doors,
      curve: const Interval(0.0, 0.88, curve: _hingeCurve),
    );
    _rightDoor = CurvedAnimation(
      parent: _doors,
      curve: const Interval(0.1, 0.98, curve: _hingeCurve),
    );
    _doorOpen = CurvedAnimation(parent: _doors, curve: _hingeCurve);
    _interiorFade = CurvedAnimation(
      parent: _interior,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );

    _enter.forward();
    _loadLocker();
    toggleWardrobeDoors = _toggleDoorsFromNav;
  }

  Future<void> _loadLocker() async {
    final locker = WardrobeLocker.instance;
    final locked = await locker.isLocked();
    final hasPin = await locker.hasPin();
    if (!mounted) return;
    setState(() {
      _isLocked = locked;
      _hasPin = hasPin;
      _lockerReady = true;
    });
  }

  @override
  void dispose() {
    if (toggleWardrobeDoors == _toggleDoorsFromNav) {
      toggleWardrobeDoors = null;
    }
    _enter.dispose();
    _knock.dispose();
    _doors.dispose();
    _interior.dispose();
    super.dispose();
  }

  /// Center nav wardrobe icon double-tap: open or close doors.
  void _toggleDoorsFromNav() {
    if (_isOpen) {
      _closeDoors();
    } else {
      _openDoors();
    }
  }

  Future<void> _openDoors() async {
    if (_isOpen) return;
    if (_isLocked) {
      await _promptUnlock();
      return;
    }
    setState(() => _isOpen = true);
    HapticFeedback.mediumImpact();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    await _knock.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _interior.forward(from: 0);
    await _doors.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.lightImpact();
  }

  Future<void> _closeDoors() async {
    if (!_isOpen) return;
    HapticFeedback.selectionClick();
    await Future.wait<void>([
      _doors.reverse(),
      Future<void>.delayed(const Duration(milliseconds: 180), () async {
        if (mounted) await _interior.reverse();
      }),
    ]);
    if (!mounted) return;
    setState(() => _isOpen = false);
  }

  Future<void> _onLeftLockerTap() async {
    if (_isOpen || _isLocked) return;
    // Show center locker, then run PIN lock flow.
    setState(() => _lockerArmed = true);
    HapticFeedback.selectionClick();
    await _runLockPinFlow();
  }

  Future<void> _onCenterLockerTap() async {
    if (_isOpen) return;
    if (_isLocked) {
      await _promptUnlock();
      return;
    }
    if (_lockerArmed) {
      await _runLockPinFlow();
    }
  }

  Future<void> _runLockPinFlow() async {
    if (_isLocked) return;

    if (!_hasPin) {
      final pin = await _showPinSheet(
        title: 'Set locker PIN',
        subtitle: 'Choose a 4-digit PIN to lock your wardrobe',
      );
      if (pin == null || !mounted) {
        if (mounted) setState(() => _lockerArmed = false);
        return;
      }
      final confirm = await _showPinSheet(
        title: 'Confirm PIN',
        subtitle: 'Enter the same 4 digits again',
      );
      if (confirm == null || !mounted) {
        if (mounted) setState(() => _lockerArmed = false);
        return;
      }
      if (confirm != pin) {
        _toast('PINs did not match');
        setState(() => _lockerArmed = false);
        return;
      }
      await WardrobeLocker.instance.setPin(pin);
      await WardrobeLocker.instance.lock();
      if (!mounted) return;
      setState(() {
        _hasPin = true;
        _isLocked = true;
        _lockerArmed = false; // left option removed while locked
      });
      HapticFeedback.heavyImpact();
      return;
    }

    final pin = await _showPinSheet(
      title: 'Lock wardrobe',
      subtitle: 'Enter your 4-digit PIN to lock',
    );
    if (pin == null || !mounted) {
      if (mounted) setState(() => _lockerArmed = false);
      return;
    }
    final ok = await WardrobeLocker.instance.verifyPin(pin);
    if (!ok) {
      _toast('Wrong PIN');
      HapticFeedback.heavyImpact();
      setState(() => _lockerArmed = false);
      return;
    }
    await WardrobeLocker.instance.lock();
    if (!mounted) return;
    setState(() {
      _isLocked = true;
      _lockerArmed = false; // left option removed while locked
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _promptUnlock() async {
    final pin = await _showPinSheet(
      title: 'Unlock wardrobe',
      subtitle: 'Enter your 4-digit locker PIN',
    );
    if (pin == null || !mounted) return;
    final ok = await WardrobeLocker.instance.verifyPin(pin);
    if (!ok) {
      _toast('Wrong PIN');
      HapticFeedback.heavyImpact();
      return;
    }
    await WardrobeLocker.instance.unlock();
    if (!mounted) return;
    setState(() {
      _isLocked = false;
      _lockerArmed = false; // left Locker option returns
    });
    HapticFeedback.lightImpact();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _showPinSheet({
    required String title,
    required String subtitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PinLockSheet(title: title, subtitle: subtitle),
    );
  }

  Future<void> _addItem({
    WardrobeCategory? category,
    String? customShelf,
  }) async {
    await showAddItemFormDialog(
      context,
      initialCategory: category,
      initialCustomShelf: customShelf,
    );
  }

  List<_ShelfRow> _rows(MineState state) {
    final byShelf = <String, List<Garment>>{};
    for (final g in state.garments) {
      byShelf.putIfAbsent(g.shelfLabel, () => []).add(g);
    }
    final rows = <_ShelfRow>[];
    final builtinByLabel = {
      for (final c in state.profile.wearer.wardrobeCategories) c.label: c,
    };
    // Prefer user shelf order (built-in + custom).
    for (final label in state.orderedShelfLabels) {
      final items = byShelf.remove(label) ?? const <Garment>[];
      final builtin = builtinByLabel[label];
      if (builtin != null) {
        rows.add(_ShelfRow(
          label: label,
          icon: builtin.icon,
          category: builtin,
          garments: items,
        ));
      } else {
        rows.add(_ShelfRow(
          label: label,
          icon: Icons.category_outlined,
          customShelf: label,
          garments: items,
        ));
      }
    }
    for (final entry in byShelf.entries) {
      rows.add(_ShelfRow(
        label: entry.key,
        icon: Icons.category_outlined,
        customShelf: entry.key,
        garments: entry.value,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final rows = _rows(state);

    return Scaffold(
      backgroundColor: const Color(0xFFC9995E),
      body: AnimatedBuilder(
        animation: Listenable.merge([_enter, _knock, _doors, _interior]),
        builder: (context, _) {
          return Opacity(
            opacity: _enterFade.value,
            child: Transform.translate(
              offset: Offset(_knockShake.value, 0),
              child: _DrawnWardrobeStage(
                leftOpen: _leftDoor.value,
                rightOpen: _rightDoor.value,
                doorOpen: _doorOpen.value,
                interiorFade: _interiorFade.value,
                isLocked: _isLocked,
                // Left only when unlocked; gone after PIN lock succeeds.
                showLeftLocker: _lockerReady &&
                    !_isLocked &&
                    !_isOpen &&
                    _doorOpen.value < 0.12,
                // Center after left tap, or while locked.
                showCenterLocker: _lockerReady &&
                    !_isOpen &&
                    _doorOpen.value < 0.12 &&
                    (_isLocked || _lockerArmed),
                rows: rows,
                onCabinetDoubleTap: _openDoors,
                onLeftLockerTap: _onLeftLockerTap,
                onCenterLockerTap: _onCenterLockerTap,
                onAdd: _addItem,
                onOpenGarment: (g) => showGarmentDetailPopup(
                  context,
                  garmentId: g.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShelfRow {
  const _ShelfRow({
    required this.label,
    required this.icon,
    required this.garments,
    this.category,
    this.customShelf,
  });

  final String label;
  final IconData icon;
  final List<Garment> garments;
  final WardrobeCategory? category;
  final String? customShelf;
}

class _DrawnWardrobeStage extends StatelessWidget {
  const _DrawnWardrobeStage({
    required this.leftOpen,
    required this.rightOpen,
    required this.doorOpen,
    required this.interiorFade,
    required this.isLocked,
    required this.showLeftLocker,
    required this.showCenterLocker,
    required this.rows,
    required this.onCabinetDoubleTap,
    required this.onLeftLockerTap,
    required this.onCenterLockerTap,
    required this.onAdd,
    required this.onOpenGarment,
  });

  final double leftOpen;
  final double rightOpen;
  final double doorOpen;
  final double interiorFade;
  final bool isLocked;
  final bool showLeftLocker;
  final bool showCenterLocker;
  final List<_ShelfRow> rows;
  final VoidCallback onCabinetDoubleTap;
  final VoidCallback onLeftLockerTap;
  final VoidCallback onCenterLockerTap;
  final Future<void> Function({WardrobeCategory? category, String? customShelf})
      onAdd;
  final ValueChanged<Garment> onOpenGarment;

  @override
  Widget build(BuildContext context) {
    // Soft room light spills as doors part.
    final reveal = ((leftOpen + rightOpen) * 0.5).clamp(0.0, 1.0);
    final openUi = doorOpen > 0.55;
    final openOpacity = ((doorOpen - 0.55) / 0.45).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _PolishedWoodBodyPainter()),
        ),
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: math.max(interiorFade, reveal * 0.85).clamp(0.0, 1.0),
                child: openUi
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Opacity(
                            opacity: openOpacity,
                            child: const _OpenWardrobeHeader(),
                          ),
                          Expanded(
                            child: _InteriorShelves(
                              rows: rows,
                              onAdd: onAdd,
                              onOpenGarment: onOpenGarment,
                            ),
                          ),
                        ],
                      )
                    : _InteriorShelves(
                        rows: rows,
                        onAdd: onAdd,
                        onOpenGarment: onOpenGarment,
                      ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _DoorSwingShadowPainter(
                    leftOpen: leftOpen,
                    rightOpen: rightOpen,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: doorOpen > 0.88,
                child: GestureDetector(
                  onDoubleTap: onCabinetDoubleTap,
                  child: _DrawnDoors(
                    leftOpen: leftOpen,
                    rightOpen: rightOpen,
                  ),
                ),
              ),
              if (showCenterLocker)
                Center(
                  child: GestureDetector(
                    onTap: onCenterLockerTap,
                    child: _SteelPadlock(locked: isLocked),
                  ),
                ),
            ],
          ),
        ),
        // Locker — centered on left door; padlock asset only.
        if (showLeftLocker)
          Positioned.fill(
            child: Align(
              // Center of the left door (midpoint of left half).
              alignment: const Alignment(-0.5, 0),
              child: _SideLockerButton(onTap: onLeftLockerTap),
            ),
          ),
        // Mine logo on closed wardrobe (open state uses header mark).
        if (!openUi)
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: MineLogoMark(size: 44, radius: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _SideLockerButton extends StatelessWidget {
  const _SideLockerButton({required this.onTap});

  final VoidCallback onTap;

  static const _asset = 'assets/nav/locker_padlock.png';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _asset,
              width: 52,
              height: 58,
              filterQuality: FilterQuality.high,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.lock_rounded,
                size: 40,
                color: Color(0xFF1C1612),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Locker',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: const Color(0xFF1C1612),
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 5,
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

/// Creative hanging objects on a brass rail — not flat chips.
class _OpenWardrobeHeader extends StatelessWidget {
  const _OpenWardrobeHeader();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _RailNichePainter(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: SizedBox(
            height: 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _HangingTag(
                    kind: _HangKind.outfit,
                    label: 'My outfit',
                    tilt: -0.04,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddClothesScreen(),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: MineLogoMark(size: 40, radius: 12),
                ),
                Expanded(
                  child: _HangingTag(
                    kind: _HangKind.bucket,
                    label: 'My Bucketlist',
                    tilt: 0.05,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BucketListScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _HangKind { outfit, bucket }

/// Dark niche + brass hanging rod the tags hang from.
class _RailNichePainter extends CustomPainter {
  const _RailNichePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4A301C),
            Color(0xFF6B4528),
            Color(0xFF3A2414),
          ],
        ).createShader(rect),
    );
    // Soft back grain
    for (var i = 0; i < 10; i++) {
      final x = size.width * (0.08 + i * 0.09);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 1, size.height),
        Paint()
          ..strokeWidth = 0.8
          ..color = const Color(0x228F5A28),
      );
    }
    // Brass rod
    final rodY = 18.0;
    final rod = Rect.fromLTWH(14, rodY - 2.5, size.width - 28, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rod, const Radius.circular(2.5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0DCA8), Color(0xFFC49A4A), Color(0xFF7A5A28)],
        ).createShader(rod),
    );
    for (final cx in [18.0, size.width - 18]) {
      canvas.drawCircle(Offset(cx, rodY), 5, Paint()..color = const Color(0xFFD4B06A));
      canvas.drawCircle(Offset(cx, rodY), 2.4, Paint()..color = const Color(0xFF5C3010));
    }
    // Bottom shelf lip
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 5, size.width, 5),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0B878), Color(0xFF8F4F1C)],
        ).createShader(Rect.fromLTWH(0, size.height - 5, size.width, 5)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Physical object: hanger or bookmark tag dangling from the rail.
class _HangingTag extends StatelessWidget {
  const _HangingTag({
    required this.kind,
    required this.label,
    required this.tilt,
    required this.onPressed,
  });

  final _HangKind kind;
  final String label;
  final double tilt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Twine / hook from rail
            Container(
              width: 2,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4B06A), Color(0xFF8F5A28)],
                ),
              ),
            ),
            if (kind == _HangKind.outfit)
              CustomPaint(
                size: const Size(36, 14),
                painter: const _MiniHangerPainter(),
              )
            else
              CustomPaint(
                size: const Size(18, 14),
                painter: const _MiniBookmarkTopPainter(),
              ),
            const SizedBox(height: 2),
            // Wooden plaque / luggage tag
            Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kind == _HangKind.outfit ? 10 : 6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: kind == _HangKind.outfit
                      ? const [
                          Color(0xFFF6E2C0),
                          Color(0xFFD4A86A),
                          Color(0xFFA86B32),
                        ]
                      : const [
                          Color(0xFFE8D5B0),
                          Color(0xFFC9A06A),
                          Color(0xFF8F5A28),
                        ],
                ),
                border: Border.all(color: const Color(0xFF4A2A10), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(1, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 4,
                    width: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        kind == _HangKind.outfit
                            ? Icons.checkroom_rounded
                            : Icons.bookmark_rounded,
                        size: 15,
                        color: const Color(0xFF3A1E08),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: const Color(0xFF2A1608),
                          ),
                        ),
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

class _MiniHangerPainter extends CustomPainter {
  const _MiniHangerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4B06A);
    final path = Path()
      ..moveTo(size.width * 0.5, 1)
      ..quadraticBezierTo(size.width * 0.62, 1, size.width * 0.58, 5)
      ..moveTo(2, size.height - 1)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width - 2, size.height - 1);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.5, 2),
      2.2,
      Paint()..color = const Color(0xFFE8D5A0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBookmarkTopPainter extends CustomPainter {
  const _MiniBookmarkTopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..lineTo(size.width - 2, size.height)
      ..lineTo(size.width * 0.5, size.height * 0.55)
      ..lineTo(2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC45A4A), Color(0xFF8B2E24)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF4A1810),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Interior fill only — doors are the full wardrobe face.
class _PolishedWoodBodyPainter extends CustomPainter {
  const _PolishedWoodBodyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE4B87A),
            Color(0xFFD0924A),
            Color(0xFFB8732E),
            Color(0xFF8F4F1C),
          ],
        ).createShader(full),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DrawnDoors extends StatelessWidget {
  const _DrawnDoors({
    required this.leftOpen,
    required this.rightOpen,
  });

  final double leftOpen;
  final double rightOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HingedDoor(
            isLeft: true,
            open: leftOpen,
          ),
        ),
        Expanded(
          child: _HingedDoor(
            isLeft: false,
            open: rightOpen,
          ),
        ),
      ],
    );
  }
}

/// Padlock on door center — uses locker asset.
class _SteelPadlock extends StatelessWidget {
  const _SteelPadlock({required this.locked});

  final bool locked;

  static const _asset = 'assets/nav/locker_padlock.png';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _asset,
          width: 78,
          height: 88,
          filterQuality: FilterQuality.high,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => CustomPaint(
            size: const Size(72, 88),
            painter: _SteelPadlockPainter(locked: locked),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          locked ? 'LOCKED' : 'Locker',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.1,
            color: const Color(0xFFE8EEF4),
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        Text(
          locked ? 'Tap to unlock' : 'Tap to lock',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 9,
            color: const Color(0xDDE8EEF4),
            shadows: const [
              Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SteelPadlockPainter extends CustomPainter {
  _SteelPadlockPainter({required this.locked});

  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.38;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, bodyTop, w * 0.76, h * 0.55),
      const Radius.circular(8),
    );

    // Shadow
    canvas.drawRRect(
      body.shift(const Offset(2, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Chrome shackle
    final shacklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF9AA3AD),
          Color(0xFFF2F5F8),
          Color(0xFF6E7781),
          Color(0xFFD7DDE3),
        ],
        stops: [0, 0.35, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, bodyTop));

    final cx = w * 0.5;
    final leftX = w * 0.28;
    final rightX = w * 0.72;
    final topY = h * 0.08;
    final insertY = bodyTop + h * 0.06;

    if (locked) {
      final path = Path()
        ..moveTo(leftX, insertY)
        ..lineTo(leftX, h * 0.28)
        ..quadraticBezierTo(leftX, topY, cx, topY)
        ..quadraticBezierTo(rightX, topY, rightX, h * 0.28)
        ..lineTo(rightX, insertY);
      canvas.drawPath(path, shacklePaint);
    } else {
      // Open shackle tilted right
      final path = Path()
        ..moveTo(leftX, insertY)
        ..lineTo(leftX, h * 0.28)
        ..quadraticBezierTo(leftX, topY, cx, topY)
        ..quadraticBezierTo(rightX + 4, topY - 2, rightX + 8, h * 0.22)
        ..lineTo(rightX + 10, h * 0.12);
      canvas.drawPath(path, shacklePaint);
    }

    // Steel body
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEEF2F6),
            Color(0xFFB0B8C2),
            Color(0xFF7A8490),
            Color(0xFF4A5560),
          ],
          stops: [0, 0.28, 0.65, 1],
        ).createShader(body.outerRect),
    );
    // Body edge
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF2F3640),
    );
    // Specular streak
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, bodyTop + 4, w * 0.18, h * 0.42),
        const Radius.circular(6),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w * 0.18, bodyTop, w * 0.25, h * 0.5)),
    );

    // Keyhole
    final kx = w * 0.5;
    final ky = bodyTop + h * 0.28;
    canvas.drawCircle(
      Offset(kx, ky),
      6,
      Paint()..color = const Color(0xFF1C2228),
    );
    canvas.drawCircle(
      Offset(kx, ky),
      3.2,
      Paint()..color = const Color(0xFF5A6570),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(kx, ky + 9), width: 5, height: 10),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF1C2228),
    );
  }

  @override
  bool shouldRepaint(covariant _SteelPadlockPainter oldDelegate) =>
      oldDelegate.locked != locked;
}

/// Outer-hinge 3D swing with thickness edge + face darkening.
class _HingedDoor extends StatelessWidget {
  const _HingedDoor({
    required this.isLeft,
    required this.open,
  });

  final bool isLeft;
  final double open;

  @override
  Widget build(BuildContext context) {
    // Almost 90° — doors park as thin side panels, still visible.
    final angle = open * (math.pi / 2) * 0.92;
    // Face darkens as it turns away from the light.
    final faceShade = (open * 0.45).clamp(0.0, 0.45);
    // Slight lift toward camera at mid-swing (perspective pop).
    final zLift = math.sin(open * math.pi) * 0.012;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.00185) // stronger perspective
      ..translateByDouble(0.0, 0.0, zLift * 80, 1.0)
      ..rotateY(isLeft ? -angle : angle);

    return Transform(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      transform: transform,
      filterQuality: FilterQuality.medium,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Door thickness (visible while swinging)
          if (open > 0.04)
            Align(
              alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              child: CustomPaint(
                size: Size(10 + open * 6, double.infinity),
                painter: _DoorEdgePainter(isLeft: isLeft, open: open),
              ),
            ),
          CustomPaint(
            painter: _DoorPanelPainter(isLeft: isLeft),
            child: const SizedBox.expand(),
          ),
          // Turning-away shade on the face
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: faceShade),
            ),
          ),
          // Specular glint that travels during open
          if (open > 0.05 && open < 0.85)
            IgnorePointer(
              child: Align(
                alignment: Alignment(-1 + open * 2.2, -0.4),
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.18 * (1 - open)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoorEdgePainter extends CustomPainter {
  _DoorEdgePainter({required this.isLeft, required this.open});

  final bool isLeft;
  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            const Color(0xFF5C3010),
            const Color(0xFF8F4F1C),
            const Color(0xFF3A1E08).withValues(alpha: 0.9),
          ],
        ).createShader(rect),
    );
    // Laminate layers
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.2 + i * 0.2);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..strokeWidth = 0.8
          ..color = Color(i.isEven ? 0x44FFE8C4 : 0x33201008),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoorEdgePainter oldDelegate) =>
      oldDelegate.open != open || oldDelegate.isLeft != isLeft;
}

/// Soft ground / cavity shadows cast by swinging doors.
class _DoorSwingShadowPainter extends CustomPainter {
  _DoorSwingShadowPainter({
    required this.leftOpen,
    required this.rightOpen,
  });

  final double leftOpen;
  final double rightOpen;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left door shadow sweeping inward then out
    if (leftOpen > 0.02) {
      final spread = w * 0.42 * math.sin(leftOpen * math.pi * 0.92);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(spread, h * 0.08)
        ..lineTo(spread * 0.85, h * 0.92)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.35 * (1 - leftOpen * 0.5)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, spread, h)),
      );
    }

    if (rightOpen > 0.02) {
      final spread = w * 0.42 * math.sin(rightOpen * math.pi * 0.92);
      final path = Path()
        ..moveTo(w, 0)
        ..lineTo(w - spread, h * 0.08)
        ..lineTo(w - spread * 0.85, h * 0.92)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Colors.black.withValues(alpha: 0.35 * (1 - rightOpen * 0.5)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(w - spread, 0, spread, h)),
      );
    }

    // Center seam light bloom as doors part
    final gap = ((leftOpen + rightOpen) * 0.5).clamp(0.0, 1.0);
    if (gap > 0.05 && gap < 0.95) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5),
          width: w * 0.08 * gap,
          height: h,
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              const Color(0xFFFFE8C4).withValues(alpha: 0.12 * (1 - gap)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(w * 0.46, 0, w * 0.08, h)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoorSwingShadowPainter oldDelegate) =>
      oldDelegate.leftOpen != leftOpen || oldDelegate.rightOpen != rightOpen;
}

class _DoorPanelPainter extends CustomPainter {
  _DoorPanelPainter({required this.isLeft});

  final bool isLeft;

  // Realistic warm oak / cognac like the nav wardrobe icon.
  static const _cream = Color(0xFFF2D9B0);
  static const _honey = Color(0xFFE4B87A);
  static const _amber = Color(0xFFD0924A);
  static const _oak = Color(0xFFB8732E);
  static const _cognac = Color(0xFF8F4F1C);
  static const _espresso = Color(0xFF5C3010);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Base oak body — warmer, deeper, icon-matched
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [_cream, _honey, _amber, _oak, _cognac],
          stops: const [0, 0.18, 0.45, 0.75, 1],
        ).createShader(rect),
    );

    // Vertical light banding (plank feel)
    for (var i = 0; i < 7; i++) {
      final x0 = w * (i / 7);
      final band = Rect.fromLTWH(x0, 0, w / 7, h);
      final dark = i.isEven;
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              (dark ? _cognac : _cream).withValues(alpha: dark ? 0.12 : 0.1),
              Colors.transparent,
              (dark ? _espresso : _honey).withValues(alpha: dark ? 0.14 : 0.08),
            ],
          ).createShader(band),
      );
    }

    // Dense organic grain
    for (var i = 0; i < 28; i++) {
      final x = w * (0.03 + i * 0.034);
      final wobble = math.sin(i * 1.7 + (isLeft ? 0.4 : 1.1)) * 2.8;
      canvas.drawLine(
        Offset(x + wobble, 1),
        Offset(x - wobble * 0.55, h - 1),
        Paint()
          ..strokeWidth = i % 3 == 0 ? 1.35 : 0.7
          ..strokeCap = StrokeCap.round
          ..color = Color(i.isEven ? 0x405C3010 : 0x288F4F1C),
      );
      if (i % 5 == 0) {
        canvas.drawLine(
          Offset(x + 1.6, 8),
          Offset(x + 0.4, h - 8),
          Paint()
            ..strokeWidth = 0.55
            ..color = const Color(0x33FFE8C4),
        );
      }
    }

    // Soft knots
    final knots = <Offset>[
      Offset(w * (isLeft ? 0.32 : 0.68), h * 0.22),
      Offset(w * (isLeft ? 0.55 : 0.4), h * 0.48),
      Offset(w * (isLeft ? 0.28 : 0.72), h * 0.74),
    ];
    for (final c in knots) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 16, height: 10),
        Paint()..color = const Color(0x288F4F1C),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 9, height: 5.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0x555C3010),
      );
    }

    // Lacquer polish (glossy varnish)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            _espresso.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.2, 0.5, 0.78, 1],
        ).createShader(rect),
    );
    // Specular streak
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, 0, w * 0.16, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Outer frame bevel
    canvas.drawRect(
      rect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _espresso,
    );
    canvas.drawRect(
      rect.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x77FFE6C0),
    );

    // Raised rectangular panel (classic armoire)
    final inset = Rect.fromLTWH(w * 0.11, h * 0.05, w * 0.78, h * 0.9);
    final panel = RRect.fromRectAndRadius(inset, const Radius.circular(5));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.14),
          ],
        ).createShader(inset),
    );
    // Panel molding: dark → light → dark
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = _espresso.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset.deflate(4), const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x66FFE8C4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset.deflate(9), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _cognac.withValues(alpha: 0.45),
    );

    // Meeting-edge shadow (doors closing together)
    canvas.drawRect(
      isLeft
          ? Rect.fromLTWH(w - 14, 0, 14, h)
          : Rect.fromLTWH(0, 0, 14, h),
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
          ],
        ).createShader(
          isLeft
              ? Rect.fromLTWH(w - 14, 0, 14, h)
              : Rect.fromLTWH(0, 0, 14, h),
        ),
    );

    // Hinge side soft shade
    canvas.drawRect(
      isLeft
          ? Rect.fromLTWH(0, 0, 10, h)
          : Rect.fromLTWH(w - 10, 0, 10, h),
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );

    // Metal handle — rounded oval pull
    final hx = isLeft ? w * 0.86 : w * 0.14;
    final hy = h * 0.5;
    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(hx + 1.5, hy + 2), width: 11, height: 36),
        const Radius.circular(5.5),
      ),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(hx, hy), width: 10, height: 34),
        const Radius.circular(5),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A4A4A), Color(0xFF121212), Color(0xFF2C2C2C)],
        ).createShader(
          Rect.fromCenter(center: Offset(hx, hy), width: 10, height: 34),
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(hx - 1.8, hy - 4), width: 3.5, height: 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _DoorPanelPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft;
}

/// Deep cupboard cavity — back panel, side walls, crown rail, hanging rod.
class _InteriorWoodPainter extends CustomPainter {
  const _InteriorWoodPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Back panel
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6B4528),
            Color(0xFF8A5A32),
            Color(0xFF5C3A20),
            Color(0xFF3A2414),
          ],
          stops: [0, 0.25, 0.7, 1],
        ).createShader(rect),
    );

    // Back grain
    for (var i = 0; i < 22; i++) {
      final x = w * (0.04 + i * 0.042);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + math.sin(i * 1.3) * 1.8, h),
        Paint()
          ..strokeWidth = 0.9
          ..color = Color(i.isEven ? 0x33201008 : 0x28C48A45),
      );
    }

    // Left / right inner walls (depth bevel)
    for (final left in [true, false]) {
      final wall = left
          ? Rect.fromLTWH(0, 0, w * 0.055, h)
          : Rect.fromLTWH(w * 0.945, 0, w * 0.055, h);
      canvas.drawRect(
        wall,
        Paint()
          ..shader = LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [
              Color(0xFF2A180C),
              Color(0xFF8F5A28),
              Color(0xFFC48A45),
            ],
          ).createShader(wall),
      );
    }

    // Center vertical divider stile
    final mid = Rect.fromLTWH(w * 0.485, 0, w * 0.03, h);
    canvas.drawRect(
      mid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF4A2A10), Color(0xFFC48A45), Color(0xFF6B3F1A)],
        ).createShader(mid),
    );

    // Soft overhead light
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            const Color(0xFFFFE8C4).withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Corner vignette
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0, 0.1, 0.9, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InteriorShelves extends StatelessWidget {
  const _InteriorShelves({
    required this.rows,
    required this.onAdd,
    required this.onOpenGarment,
  });

  final List<_ShelfRow> rows;
  final Future<void> Function({WardrobeCategory? category, String? customShelf})
      onAdd;
  final ValueChanged<Garment> onOpenGarment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _InteriorWoodPainter()),
        ListView.builder(
          // Rows clear the floating bottom nav (shell dockClearance).
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          physics: const BouncingScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return _CupboardBay(
              row: row,
              bayIndex: index,
              onAdd: () => onAdd(
                category: row.category,
                customShelf: row.customShelf,
              ),
              onOpenGarment: onOpenGarment,
            );
          },
        ),
      ],
    );
  }
}

/// One carved cupboard bay: plank, rod, recessed shelf space, items.
class _CupboardBay extends StatelessWidget {
  const _CupboardBay({
    required this.row,
    required this.bayIndex,
    required this.onAdd,
    required this.onOpenGarment,
  });

  final _ShelfRow row;
  final int bayIndex;
  final VoidCallback onAdd;
  final ValueChanged<Garment> onOpenGarment;

  bool get _isHangBay => bayIndex % 3 != 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thick shelf plank
          CustomPaint(
            painter: const _ShelfPlankPainter(),
            child: SizedBox(
              height: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(row.icon, size: 12, color: const Color(0xFF3A2414)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A2414),
                        ),
                      ),
                    ),
                    Text(
                      '${row.garments.length}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B3F1A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Recessed bay
          Container(
            height: _isHangBay ? 108 : 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2E1C10).withValues(alpha: 0.55),
                  const Color(0xFF5C3A20),
                  const Color(0xFF4A2A10),
                ],
              ),
              border: Border(
                left: BorderSide(
                  color: const Color(0xFFC48A45).withValues(alpha: 0.45),
                  width: 2,
                ),
                right: BorderSide(
                  color: const Color(0xFFC48A45).withValues(alpha: 0.45),
                  width: 2,
                ),
                bottom: BorderSide(
                  color: const Color(0xFFE0B878).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Inner wood grain wash
                Positioned.fill(
                  child: CustomPaint(painter: _BayGrainPainter(seed: bayIndex)),
                ),
                // Hanging rod for hang bays
                if (_isHangBay)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 10,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7A5A28),
                            Color(0xFFE8D5A0),
                            Color(0xFFB0894F),
                            Color(0xFF7A5A28),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Items
                Positioned.fill(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(
                      10,
                      _isHangBay ? 20 : 10,
                      10,
                      8,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: row.garments.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == row.garments.length) {
                        return _AddSlot(onTap: onAdd, hang: _isHangBay);
                      }
                      final g = row.garments[index];
                      return _GarmentSlot(
                        garment: g,
                        hang: _isHangBay,
                        onTap: () => onOpenGarment(g),
                        onZoom: () => onOpenGarment(g),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfPlankPainter extends CustomPainter {
  const _ShelfPlankPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF0D4A8),
            Color(0xFFD4A86A),
            Color(0xFFA86B32),
            Color(0xFF8F5A28),
          ],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(rect),
    );
    // Front edge highlight
    canvas.drawLine(
      Offset(4, 1.5),
      Offset(size.width - 4, 1.5),
      Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0x88FFE8C4),
    );
    // Grain
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.25 + i * 0.08);
      canvas.drawLine(
        Offset(6, y),
        Offset(size.width - 6, y + math.sin(i) * 0.6),
        Paint()
          ..strokeWidth = 0.6
          ..color = const Color(0x336B3F1A),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BayGrainPainter extends CustomPainter {
  _BayGrainPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final x = size.width * (0.08 + i * 0.09);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + math.sin(seed + i) * 1.5, size.height),
        Paint()
          ..strokeWidth = 0.7
          ..color = Color((seed + i).isEven ? 0x22201008 : 0x18C48A45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BayGrainPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap, required this.hang});

  final VoidCallback onTap;
  final bool hang;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            if (hang)
              Container(
                width: 2,
                height: 10,
                color: const Color(0xFFB0894F).withValues(alpha: 0.7),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: const Color(0xFFE8C98A).withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarmentSlot extends StatelessWidget {
  const _GarmentSlot({
    required this.garment,
    required this.hang,
    required this.onTap,
    required this.onZoom,
  });

  final Garment garment;
  final bool hang;
  final VoidCallback onTap;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onZoom,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            if (hang) ...[
              Container(
                width: 2,
                height: 8,
                color: const Color(0xFFB0894F),
              ),
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: const Color(0xFFD4B06A),
                ),
              ),
              const SizedBox(height: 2),
            ],
            Expanded(
              child: PhotoTile(
                garment: garment,
                radius: 8,
                fit: BoxFit.contain,
                backgroundColor: const Color(0xFFF6EDE3),
              ),
            ),
            if (garment.cost != null) ...[
              const SizedBox(height: 3),
              Text(
                '₹${garment.cost!.round()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF6EDE3),
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 4-digit PIN pad for lock / unlock.
class _PinLockSheet extends StatefulWidget {
  const _PinLockSheet({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<_PinLockSheet> createState() => _PinLockSheetState();
}

class _PinLockSheetState extends State<_PinLockSheet> {
  String _pin = '';

  void _tap(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) Navigator.of(context).pop(_pin);
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 12 + bottom),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8EEF4),
            Color(0xFFB0B8C2),
            Color(0xFF7A8490),
          ],
        ),
        border: Border.all(color: const Color(0xFF2F3640), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x662F3640),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Icon(
            Icons.lock_rounded,
            size: 28,
            color: Color(0xFF1C2228),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: const Color(0xFF1C2228),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: const Color(0xFF3A4450),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: filled ? 16 : 14,
                height: filled ? 16 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? const Color(0xFF1C2228)
                      : const Color(0x44FFFFFF),
                  border: Border.all(
                    color: const Color(0xFF2F3640),
                    width: 1.4,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: key.isEmpty
                            ? const SizedBox(height: 48)
                            : Material(
                                color: Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () =>
                                      key == '⌫' ? _backspace() : _tap(key),
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: Text(
                                        key,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: key == '⌫' ? 18 : 20,
                                          color: const Color(0xFF1C2228),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A4450),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
