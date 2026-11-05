import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_nav.dart';
import '../models/jewelry.dart';
import '../models/wardrobe.dart';
import '../models/wardrobe_decor.dart';
import '../services/metal_prices.dart';
import '../services/wardrobe_decor_store.dart';
import '../services/wardrobe_locker.dart';
import '../state/mine_state.dart';
import '../widgets/add_item_form_dialog.dart';
import '../widgets/common.dart';
import '../widgets/mine_logo_mark.dart';
import '../widgets/wardrobe_decor_palette.dart';
import '../widgets/wardrobe_decor_sticker.dart';
import '../widgets/wardrobe_weather_sky.dart';
import 'add_clothes_screen.dart';
import 'bucket_list_screen.dart';
import 'garment_detail_screen.dart';
import 'jewelry_drawer_screen.dart';

/// Closed view is the polished armoire. Double-tap the doors (or tap a
/// drawer) to swing them open onto the shelves.
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

  final _decor = WardrobeDecorController();

  /// Heavy door: slow push, faster swing, soft stop.
  static const _hingeCurve = Cubic(0.42, 0.04, 0.16, 1.0);

  @override
  void initState() {
    super.initState();
    _decor.load();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _knock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _doors = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1760),
    );
    _interior = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _enterFade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _knockShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -1.8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -1.8, end: 2.6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 2.6, end: -0.7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.7, end: 0), weight: 2),
    ]).animate(CurvedAnimation(parent: _knock, curve: Curves.easeOut));

    // Left leads; right follows — one hand, then the other.
    _leftDoor = CurvedAnimation(
      parent: _doors,
      curve: const Interval(0.0, 0.86, curve: _hingeCurve),
    );
    _rightDoor = CurvedAnimation(
      parent: _doors,
      curve: const Interval(0.14, 1.0, curve: _hingeCurve),
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
    _decor.dispose();
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
      if (Jewelry.isPiece(g)) continue;
      byShelf.putIfAbsent(g.shelfLabel, () => []).add(g);
    }
    final rows = <_ShelfRow>[];
    final builtinByLabel = {
      for (final c in state.profile.wearer.wardrobeCategories) c.label: c,
    };
    // Prefer user shelf order (built-in + custom).
    void sortShelf(List<Garment> items) {
      items.sort((a, b) {
        final byIndex = a.shelfIndex.compareTo(b.shelfIndex);
        if (byIndex != 0) return byIndex;
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    for (final label in state.orderedShelfLabels) {
      final items = List<Garment>.from(byShelf.remove(label) ?? const <Garment>[]);
      sortShelf(items);
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
      final items = List<Garment>.from(entry.value);
      sortShelf(items);
      rows.add(_ShelfRow(
        label: entry.key,
        icon: Icons.category_outlined,
        customShelf: entry.key,
        garments: items,
      ));
    }
    return rows;
  }

  Future<void> _stripRowBackgrounds(_ShelfRow row) async {
    final withPhotos = row.garments
        .where((g) => g.imagePath != null && g.imagePath!.trim().isNotEmpty)
        .length;
    if (withPhotos == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No photos in ${row.label} yet.')),
      );
      return;
    }

    var done = 0;
    var total = withPhotos;
    final progress = ValueNotifier<(int, int)>((0, total));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Removing backgrounds'),
            content: ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (_, value, _) {
                final d = value.$1;
                final t = value.$2;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row: ${row.label}\n$d of $t photos…',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: t == 0 ? null : d / t,
                      color: const Color(0xFFC45C26),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    try {
      await context.read<MineState>().stripShelfBackgrounds(
            row.label,
            onProgress: (d, t) {
              done = d;
              total = t;
              progress.value = (d, t);
            },
          );
    } finally {
      progress.dispose();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done == 0
              ? 'Nothing to cut in ${row.label}.'
              : 'Background removed on $done ${done == 1 ? 'photo' : 'photos'} in ${row.label}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final rows = _rows(state);
    final pieces = rows.fold<int>(0, (sum, row) => sum + row.garments.length);

    return ListenableBuilder(
      listenable: _decor,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFE6D2BC),
          body: AnimatedBuilder(
            animation: Listenable.merge([_enter, _knock, _doors, _interior]),
            builder: (context, _) {
              return Opacity(
                opacity: _enterFade.value,
                child: Transform.translate(
                  offset: Offset(_knockShake.value, 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _DrawnWardrobeStage(
                        leftOpen: _leftDoor.value,
                        rightOpen: _rightDoor.value,
                        doorOpen: _doorOpen.value,
                        interiorFade: _interiorFade.value,
                        isLocked: _isLocked,
                        pieceCount: pieces,
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
                        decor: _decor,
                        onCabinetDoubleTap: _openDoors,
                        onLeftLockerTap: _onLeftLockerTap,
                        onCenterLockerTap: _onCenterLockerTap,
                        onCustomize: () {
                          if (!_isOpen) {
                            _openDoors();
                          }
                          _decor.setCustomizeMode(true);
                        },
                        onAdd: _addItem,
                        onOpenGarment: (g) => showGarmentDetailPopup(
                          context,
                          garmentId: g.id,
                        ),
                        onStripRow: _stripRowBackgrounds,
                        onReorderRow: (label, oldIndex, newIndex) => context
                            .read<MineState>()
                            .reorderShelfGarments(label, oldIndex, newIndex),
                      ),
                      if (_decor.customizeMode && _isOpen)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: WardrobeDecorPalette(
                            onDone: () => _decor.setCustomizeMode(false),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
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
    required this.pieceCount,
    required this.showLeftLocker,
    required this.showCenterLocker,
    required this.rows,
    required this.decor,
    required this.onCabinetDoubleTap,
    required this.onLeftLockerTap,
    required this.onCenterLockerTap,
    required this.onCustomize,
    required this.onAdd,
    required this.onOpenGarment,
    required this.onStripRow,
    required this.onReorderRow,
  });

  final double leftOpen;
  final double rightOpen;
  final double doorOpen;
  final double interiorFade;
  final bool isLocked;
  final int pieceCount;
  final bool showLeftLocker;
  final bool showCenterLocker;
  final List<_ShelfRow> rows;
  final WardrobeDecorController decor;
  final VoidCallback onCabinetDoubleTap;
  final VoidCallback onLeftLockerTap;
  final VoidCallback onCenterLockerTap;
  final VoidCallback onCustomize;
  final Future<void> Function({WardrobeCategory? category, String? customShelf})
      onAdd;
  final ValueChanged<Garment> onOpenGarment;
  final Future<void> Function(_ShelfRow row) onStripRow;
  final Future<void> Function(String shelfLabel, int oldIndex, int newIndex)
      onReorderRow;

  @override
  Widget build(BuildContext context) {
    final reveal = ((leftOpen + rightOpen) * 0.5).clamp(0.0, 1.0);
    // Header tags appear once the cavity has opened into the full cupboard.
    final openUi = doorOpen > 0.86;
    final openOpacity = ((doorOpen - 0.86) / 0.14).clamp(0.0, 1.0);
    final expand = ((doorOpen - 0.70) / 0.30).clamp(0.0, 1.0);
    final cabinetFade = (1 - expand).clamp(0.0, 1.0);

    final interior = Opacity(
      opacity: math.max(interiorFade, reveal * 0.92).clamp(0.0, 1.0),
      child: openUi
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Opacity(
                  opacity: openOpacity,
                  child: _OpenWardrobeHeader(onCustomize: onCustomize),
                ),
                Expanded(
                  child: _InteriorShelves(
                    rows: rows,
                    decor: decor,
                    bottomInset: 18 +
                        MediaQuery.paddingOf(context).bottom +
                        (decor.customizeMode ? 150 : 0),
                    onAdd: onAdd,
                    onOpenGarment: onOpenGarment,
                    onStripRow: onStripRow,
                    onReorderRow: onReorderRow,
                  ),
                ),
              ],
            )
          : _InteriorShelves(
              rows: rows,
              decor: decor,
              bottomInset: 8,
              onAdd: onAdd,
              onOpenGarment: onOpenGarment,
              onStripRow: onStripRow,
              onReorderRow: onReorderRow,
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final safeTop = MediaQuery.paddingOf(context).top;
        // Weather only when cupboard is closed. Inside open shelves = no sky.
        final weatherOut = (1.0 - expand).clamp(0.0, 1.0);
        final skyBody = 20.0 + 128.0 * weatherOut;
        final skyBand = safeTop + skyBody;
        const rateBand = 66.0;
        // Keep rates just above the smile dock — no empty wall under the cupboard.
        final floorGap = MediaQuery.paddingOf(context).bottom + 2 + rateBand;
        const aspect = 1024 / 935;
        final availH = math.max(160.0, maxH - floorGap - skyBand - 8);
        var cabW = maxW * 0.995;
        var cabH = cabW * aspect;
        if (cabH > availH) {
          cabH = availH;
          cabW = cabH / aspect;
        }
        final left = (maxW - cabW) / 2;
        final minTop = skyBand + (weatherOut > 0.2 ? 10.0 : 4.0);
        final top = math.max(minTop, maxH - floorGap - cabH);

        const doorTop = _PhotoArmoire.doorTop;
        const doorBottom = _PhotoArmoire.doorBottom;
        const doorInner = _PhotoArmoire.doorInner;
        final cavity = Rect.fromLTWH(
          left + cabW * doorInner,
          top + cabH * doorTop,
          cabW * (1 - doorInner * 2),
          cabH * (doorBottom - doorTop),
        );
        // Open shelves fill the chamber — weather stays outside / hidden when open.
        final full = Rect.fromLTWH(
          0,
          weatherOut > 0.15 ? skyBand + 2 : safeTop + 2,
          maxW,
          maxH - (weatherOut > 0.15 ? skyBand + 2 : safeTop + 2),
        );
        final hole = Rect.lerp(cavity, full, expand)!;
        // Keep the name plaque below the outdoor sky so it never covers weather.
        final plaqueTop = math.max(skyBand + 4, top - 40);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _RoomBackdropPainter()),
            ),
            // Outdoor weather only above a closed cupboard — never inside shelves.
            if (weatherOut > 0.02)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: skyBand + 8,
                child: IgnorePointer(
                  ignoring: weatherOut < 0.4,
                  child: Opacity(
                    opacity: weatherOut,
                    child: WardrobeWeatherSky(height: skyBody),
                  ),
                ),
              ),
            Positioned.fromRect(
              rect: hole,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10 * (1 - expand)),
                child: ColoredBox(
                  color: const Color(0xFF3A2414),
                  child: interior,
                ),
              ),
            ),
            Positioned(
              left: left + cabW * 0.2,
              top: top + cabH * 0.93,
              width: cabW * 0.6,
              height: 26,
              child: Opacity(
                opacity: 0.55 * cabinetFade,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xAA3A2414),
                        blurRadius: 18,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: cabW,
              height: cabH,
              child: Opacity(
                opacity: cabinetFade,
                child: IgnorePointer(
                  ignoring: doorOpen > 0.84,
                  child: _PhotoArmoire(
                    leftOpen: leftOpen,
                    rightOpen: rightOpen,
                    locked: isLocked,
                    onOpen: onCabinetDoubleTap,
                    onGold: () => _openJewelDrawer(context, gold: true),
                    onSilver: () => _openJewelDrawer(context, gold: false),
                  ),
                ),
              ),
            ),
            if (doorOpen < 0.08)
              Positioned(
                left: left + cabW * doorInner,
                top: top + cabH * doorTop,
                width: cabW * (1 - doorInner * 2),
                height: cabH * (doorBottom - doorTop),
                child: const IgnorePointer(child: _CabinetSheen()),
              ),
            if (cabinetFade > 0.4)
              Positioned(
                left: 24,
                right: 24,
                top: plaqueTop,
                child: Opacity(
                  opacity: ((cabinetFade - 0.4) / 0.6).clamp(0.0, 1.0),
                  child: _WardrobePlaque(
                    pieces: pieceCount,
                    locked: isLocked,
                  ),
                ),
              ),
            if (showLeftLocker)
              Positioned(
                left: left + cabW * 0.33 - 34,
                top: top + cabH * 0.22,
                child: _SideLockerButton(onTap: onLeftLockerTap),
              ),
            if (showCenterLocker)
              Positioned(
                left: left + cabW * 0.5 - 52,
                top: top + cabH * 0.40,
                child: _HungLock(
                  locked: isLocked,
                  onTap: onCenterLockerTap,
                ),
              ),
            if (!openUi && !showCenterLocker && cabinetFade > 0.55)
              Positioned(
                left: 20,
                right: 20,
                top: top + cabH * 0.67,
                child: Opacity(
                  opacity: cabinetFade,
                  child: const _OpenHint(),
                ),
              ),
            if (!openUi)
              Positioned(
                left: left + 10,
                width: math.max(0, cabW - 20),
                top: top + cabH + 4,
                height: rateBand - 4,
                child: Opacity(
                  opacity: cabinetFade,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _JewelPriceBar(
                      locked: isLocked,
                      onLocked: onCabinetDoubleTap,
                      onGold: () => _openJewelDrawer(context, gold: true),
                      onSilver: () => _openJewelDrawer(context, gold: false),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Fractions of `assets/nav/wardrobe_icon.png` (crown, door panels, drawers, feet).
Future<void> _openJewelDrawer(BuildContext context, {required bool gold}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => JewelryDrawerScreen(gold: gold)),
  );
}

class _PhotoArmoire extends StatelessWidget {
  const _PhotoArmoire({
    required this.leftOpen,
    required this.rightOpen,
    required this.locked,
    required this.onOpen,
    required this.onGold,
    required this.onSilver,
  });

  final double leftOpen;
  final double rightOpen;
  final bool locked;
  final VoidCallback onOpen;
  final Future<void> Function() onGold;
  final Future<void> Function() onSilver;

  static const doorTop = 0.132;
  static const doorBottom = 0.758;
  static const doorInner = 0.228;
  static const drawerTop = 0.758;
  static const drawerBottom = 0.866;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            const Expanded(
              flex: 132,
              child: _ImageBand(top: 0, bottom: doorTop),
            ),
            const Expanded(
              flex: 626,
              child: SizedBox.expand(),
            ),
            Expanded(
              flex: 108,
              child: _PhotoDrawers(
                locked: locked,
                onLocked: onOpen,
                onGold: onGold,
                onSilver: onSilver,
              ),
            ),
            const Expanded(
              flex: 134,
              child: _ImageBand(top: drawerBottom, bottom: 1),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final doorH = h * (doorBottom - doorTop);
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: h * doorTop,
                  height: doorH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth * doorInner,
                        child: const _ImageBand(
                          top: doorTop,
                          bottom: doorBottom,
                          cropLeft: 0,
                          cropRight: doorInner,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: onOpen,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _PhotoDoor(isLeft: true, open: leftOpen),
                              ),
                              Expanded(
                                child: _PhotoDoor(isLeft: false, open: rightOpen),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth * doorInner,
                        child: const _ImageBand(
                          top: doorTop,
                          bottom: doorBottom,
                          cropLeft: 1 - doorInner,
                          cropRight: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PhotoDoor extends StatelessWidget {
  const _PhotoDoor({required this.isLeft, required this.open});

  final bool isLeft;
  final double open;

  @override
  Widget build(BuildContext context) {
    final angle = open * (math.pi / 2) * 0.94;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0024)
      ..rotateY(isLeft ? -angle : angle);
    return Transform(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      filterQuality: FilterQuality.medium,
      transform: transform,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ImageBand(
            top: _PhotoArmoire.doorTop,
            bottom: _PhotoArmoire.doorBottom,
            cropLeft: isLeft ? _PhotoArmoire.doorInner : 0.5,
            cropRight: isLeft ? 0.5 : 1 - _PhotoArmoire.doorInner,
          ),
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: (open * 0.4).clamp(0.0, 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoDrawers extends StatefulWidget {
  const _PhotoDrawers({
    required this.locked,
    required this.onLocked,
    required this.onGold,
    required this.onSilver,
  });

  final bool locked;
  final VoidCallback onLocked;
  final Future<void> Function() onGold;
  final Future<void> Function() onSilver;

  @override
  State<_PhotoDrawers> createState() => _PhotoDrawersState();
}

class _PhotoDrawersState extends State<_PhotoDrawers>
    with TickerProviderStateMixin {
  late final AnimationController _left;
  late final AnimationController _right;

  @override
  void initState() {
    super.initState();
    _left = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _right = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  Future<void> _tap({required bool gold}) async {
    if (widget.locked) {
      widget.onLocked();
      return;
    }
    final pull = gold ? _left : _right;
    if (pull.isAnimating) return;
    HapticFeedback.lightImpact();
    await pull.forward(from: 0);
    if (!mounted) return;
    await (gold ? widget.onGold() : widget.onSilver());
    if (mounted) await pull.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DrawerHalf(
            pull: _left,
            cropLeft: 0,
            cropRight: 0.5,
            label: 'GOLD',
            onTap: () => _tap(gold: true),
          ),
        ),
        Expanded(
          child: _DrawerHalf(
            pull: _right,
            cropLeft: 0.5,
            cropRight: 1,
            label: 'SILVER',
            onTap: () => _tap(gold: false),
          ),
        ),
      ],
    );
  }
}

class _DrawerHalf extends StatelessWidget {
  const _DrawerHalf({
    required this.pull,
    required this.cropLeft,
    required this.cropRight,
    required this.label,
    required this.onTap,
  });

  final AnimationController pull;
  final double cropLeft;
  final double cropRight;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: pull,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(pull.value);
          return Transform.translate(
            offset: Offset(0, 14 * t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32 * t),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ImageBand(
              top: _PhotoArmoire.drawerTop,
              bottom: _PhotoArmoire.drawerBottom,
              cropLeft: cropLeft,
              cropRight: cropRight,
            ),
            Align(
              alignment: const Alignment(0, 0.72),
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF3A2414),
                  shadows: const [
                    Shadow(color: Color(0xAAFFF1D4), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JewelPriceBar extends StatefulWidget {
  const _JewelPriceBar({
    required this.locked,
    required this.onLocked,
    required this.onGold,
    required this.onSilver,
  });

  final bool locked;
  final VoidCallback onLocked;
  final Future<void> Function() onGold;
  final Future<void> Function() onSilver;

  @override
  State<_JewelPriceBar> createState() => _JewelPriceBarState();
}

class _JewelPriceBarState extends State<_JewelPriceBar> {
  MetalQuote? _quote;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final quote = await MetalPrices.instance.fetch();
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open(bool gold) async {
    if (widget.locked) {
      widget.onLocked();
      return;
    }
    await (gold ? widget.onGold() : widget.onSilver());
  }

  String? _worthLine(
    Iterable<Garment> pieces,
    double Function(JewelryFacts facts) rate,
  ) {
    final worth = Jewelry.worth(pieces, rate);
    if (worth.purchased == null && worth.current == null) return null;
    final paid = worth.purchased == null ? '—' : formatInr(worth.purchased!);
    final now = worth.current == null ? '—' : formatInr(worth.current!);
    return 'Purchased $paid\nCurrent $now';
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final garments = context.watch<MineState>().garments;
    final goldText = quote == null
        ? (_failed ? 'Gold price unavailable' : 'Gold …')
        : 'Gold 22K ${formatInr(quote.goldPerGram(22))}/g';
    final silverText = quote == null
        ? (_failed ? 'Retry' : 'Silver …')
        : 'Silver ${formatInr(quote.silver999InrPerGram)}/g';
    final goldWorth = quote == null
        ? null
        : _worthLine(
            garments.where(Jewelry.isGold),
            (facts) => quote.goldPerGram(facts.purity),
          );
    final silverWorth = quote == null
        ? null
        : _worthLine(
            garments.where((piece) => Jewelry.isPiece(piece) && !Jewelry.isGold(piece)),
            (facts) => quote.silverPerGram(facts.purity),
          );
    return Row(
      children: [
        Expanded(
          child: _PriceChip(
            text: goldText,
            detail: goldWorth,
            gold: true,
            onTap: _failed && quote == null ? _load : () => _open(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PriceChip(
            text: silverText,
            detail: silverWorth,
            gold: false,
            onTap: _failed && quote == null ? _load : () => _open(false),
          ),
        ),
      ],
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.text,
    required this.gold,
    required this.onTap,
    this.detail,
  });

  final String text;
  final String? detail;
  final bool gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = gold ? const Color(0xFFE8C56A) : const Color(0xFFE6E8EC);
    return Material(
      color: const Color(0xE61C140C),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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

/// One crop of the armoire artwork, scaled to the slot.
class _ImageBand extends StatelessWidget {
  const _ImageBand({
    required this.top,
    required this.bottom,
    this.cropLeft = 0,
    this.cropRight = 1,
  });

  final double top;
  final double bottom;
  final double cropLeft;
  final double cropRight;

  static const asset = 'assets/nav/wardrobe_icon.png';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bandW = constraints.maxWidth;
        final bandH = constraints.maxHeight;
        if (bandW <= 0 || bandH <= 0) return const SizedBox.shrink();
        final fracW = (cropRight - cropLeft).clamp(0.001, 1.0);
        final fracH = (bottom - top).clamp(0.001, 1.0);
        final fullW = bandW / fracW;
        final fullH = bandH / fracH;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: fullW,
            maxWidth: fullW,
            minHeight: fullH,
            maxHeight: fullH,
            child: Transform.translate(
              offset: Offset(-fullW * cropLeft, -fullH * top),
              child: Image.asset(
                asset,
                width: fullW,
                height: fullH,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WardrobePlaque extends StatelessWidget {
  const _WardrobePlaque({required this.pieces, required this.locked});

  final int pieces;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final count = pieces == 1 ? '1 piece inside' : '$pieces pieces inside';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xE8FFF6E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF8A4E16), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WARDROBE',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: const Color(0xFF6B3F1A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              locked ? 'Locked · $count' : count,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3A2414),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenHint extends StatelessWidget {
  const _OpenHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC2A1608),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x66FFE8C4)),
        ),
        child: Text(
          'Double-tap the doors',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: const Color(0xFFF6E2C0),
          ),
        ),
      ),
    );
  }
}

class _CabinetSheen extends StatefulWidget {
  const _CabinetSheen();

  @override
  State<_CabinetSheen> createState() => _CabinetSheenState();
}

class _CabinetSheenState extends State<_CabinetSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final x = -1.3 + _sweep.value * 2.6;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - 0.35, -0.2),
              end: Alignment(x + 0.35, 0.8),
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.13),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoomBackdropPainter extends CustomPainter {
  const _RoomBackdropPainter();

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
            Color(0xFFF6E7D6),
            Color(0xFFE7D0B6),
            Color(0xFFD7B896),
            Color(0xFFC6A484),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.85),
          radius: 1.15,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    final floorTop = size.height * 0.78;
    final floor = Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC9A06C), Color(0xFF8D5A34), Color(0xFF5C3A22)],
        ).createShader(floor),
    );
    for (var i = 0; i < 7; i++) {
      final y = floorTop + (size.height - floorTop) * (i / 7);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0x335C3010),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop - 7, size.width, 7),
      Paint()..color = const Color(0xFF8A6238),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HungLock extends StatefulWidget {
  const _HungLock({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback onTap;

  @override
  State<_HungLock> createState() => _HungLockState();
}

class _HungLockState extends State<_HungLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway;

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _sway,
        builder: (context, child) {
          return Transform.rotate(
            angle: (_sway.value - 0.5) * 0.07,
            alignment: const Alignment(0, -0.65),
            child: child,
          );
        },
        child: _SteelPadlock(locked: widget.locked),
      ),
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3DC),
              Color(0xFFE4B86A),
              Color(0xFFB8893E),
            ],
          ),
          border: Border.all(color: const Color(0xFF5C3A18), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _asset,
              width: 40,
              height: 46,
              filterQuality: FilterQuality.high,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.lock_rounded,
                size: 32,
                color: Color(0xFF3A2414),
              ),
            ),
            Text(
              'LOCK',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1.3,
                color: const Color(0xFF3A2414),
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
  const _OpenWardrobeHeader({required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _RailNichePainter(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: SizedBox(
            height: 92,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const MineLogoMark(size: 36, radius: 11),
                      const SizedBox(height: 2),
                      _HangingTag(
                        kind: _HangKind.customize,
                        label: 'Customize',
                        tilt: 0,
                        compact: true,
                        onPressed: onCustomize,
                      ),
                    ],
                  ),
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

enum _HangKind { outfit, bucket, customize }

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
    this.compact = false,
  });

  final _HangKind kind;
  final String label;
  final double tilt;
  final VoidCallback onPressed;
  final bool compact;

  IconData get _icon => switch (kind) {
        _HangKind.outfit => Icons.checkroom_rounded,
        _HangKind.bucket => Icons.bookmark_rounded,
        _HangKind.customize => Icons.auto_awesome_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 8.0 : 12.0;
    final padV = compact ? 5.0 : 8.0;
    final fontSize = compact ? 10.0 : 12.0;
    final iconSize = compact ? 12.0 : 15.0;
    return GestureDetector(
      onTap: onPressed,
      child: Transform.rotate(
        angle: tilt,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
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
              else if (kind == _HangKind.bucket)
                CustomPaint(
                  size: const Size(18, 14),
                  painter: const _MiniBookmarkTopPainter(),
                )
              else
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFFE8D5A0),
                ),
              const SizedBox(height: 2),
            ],
            Container(
              constraints: BoxConstraints(minHeight: compact ? 28 : 40),
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  kind == _HangKind.outfit ? 10 : 6,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: kind == _HangKind.customize
                      ? const [
                          Color(0xFFFFF1D4),
                          Color(0xFFE0B878),
                          Color(0xFFC45C26),
                        ]
                      : kind == _HangKind.outfit
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: iconSize, color: const Color(0xFF3A1E08)),
                  SizedBox(width: compact ? 3 : 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: fontSize,
                        color: const Color(0xFF2A1608),
                      ),
                    ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xE62A1608),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                locked ? 'LOCKED' : 'LOCKER',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: const Color(0xFFF6E2C0),
                ),
              ),
              Text(
                locked ? 'Tap to unlock' : 'Tap to lock',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                  color: const Color(0xFFE8D5B0),
                ),
              ),
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
    required this.decor,
    required this.bottomInset,
    required this.onAdd,
    required this.onOpenGarment,
    required this.onStripRow,
    required this.onReorderRow,
  });

  final List<_ShelfRow> rows;
  final WardrobeDecorController decor;
  final double bottomInset;
  final Future<void> Function({WardrobeCategory? category, String? customShelf})
      onAdd;
  final ValueChanged<Garment> onOpenGarment;
  final Future<void> Function(_ShelfRow row) onStripRow;
  final Future<void> Function(String shelfLabel, int oldIndex, int newIndex)
      onReorderRow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _InteriorWoodPainter()),
        ListView.builder(
          // Rows clear the floating bottom nav (shell dockClearance).
          padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset),
          physics: const BouncingScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return _CupboardBay(
              row: row,
              bayIndex: index,
              placements: decor.forShelf(row.label),
              customizeMode: decor.customizeMode,
              onDropDecor: (decorId) => decor.addToShelf(row.label, decorId),
              onRemoveDecor: decor.removePlacement,
              onStripRow: () => onStripRow(row),
              onReorder: (oldIndex, newIndex) =>
                  onReorderRow(row.label, oldIndex, newIndex),
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
    required this.placements,
    required this.customizeMode,
    required this.onDropDecor,
    required this.onRemoveDecor,
    required this.onStripRow,
    required this.onReorder,
    required this.onAdd,
    required this.onOpenGarment,
  });

  final _ShelfRow row;
  final int bayIndex;
  final List<WardrobeDecorPlacement> placements;
  final bool customizeMode;
  final ValueChanged<String> onDropDecor;
  final ValueChanged<String> onRemoveDecor;
  final VoidCallback onStripRow;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;
  final ValueChanged<Garment> onOpenGarment;

  bool get _isHangBay => bayIndex % 3 != 2;

  @override
  Widget build(BuildContext context) {
    final topPad = _isHangBay ? 20.0 : 10.0;
    final bay = Container(
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
            color: customizeMode
                ? const Color(0xFFE8D5A0)
                : const Color(0xFFC48A45).withValues(alpha: 0.45),
            width: customizeMode ? 2.5 : 2,
          ),
          right: BorderSide(
            color: customizeMode
                ? const Color(0xFFE8D5A0)
                : const Color(0xFFC48A45).withValues(alpha: 0.45),
            width: customizeMode ? 2.5 : 2,
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
          Positioned.fill(
            child: CustomPaint(painter: _BayGrainPainter(seed: bayIndex)),
          ),
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
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, topPad, 8, 8),
              child: Row(
                children: [
                  for (final place in placements) ...[
                    WardrobeDecorSticker(
                      kind: place.kind ?? wardrobeDecorCatalog.first,
                      size: _isHangBay ? 58 : 52,
                      onLongPress: () => onRemoveDecor(place.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: row.garments.isEmpty
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: _AddSlot(onTap: onAdd, hang: _isHangBay),
                          )
                        : ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 6,
                                child: child,
                              );
                            },
                            onReorderItem: onReorder,
                            itemCount: row.garments.length,
                            itemBuilder: (context, index) {
                              final g = row.garments[index];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(g.id),
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _GarmentSlot(
                                    garment: g,
                                    hang: _isHangBay,
                                    onTap: () => onOpenGarment(g),
                                    onZoom: () => onOpenGarment(g),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (row.garments.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _AddSlot(onTap: onAdd, hang: _isHangBay),
                  ],
                ],
              ),
            ),
          ),
          if (customizeMode)
            Positioned(
              right: 8,
              top: 6,
              child: Text(
                'Drop here',
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE8D5A0),
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPaint(
            painter: const _ShelfPlankPainter(),
            child: SizedBox(
              height: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      '${row.garments.length}'
                      '${placements.isEmpty ? '' : ' · ${placements.length} decor'}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B3F1A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Remove backgrounds in this row',
                      child: InkWell(
                        onTap: onStripRow,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.auto_fix_high_rounded,
                            size: 15,
                            color: Color(0xFF3A2414),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => onDropDecor(details.data),
            builder: (context, candidate, rejected) {
              final hovering = candidate.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  boxShadow: hovering
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE8D5A0)
                                .withValues(alpha: 0.55),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: bay,
              );
            },
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
