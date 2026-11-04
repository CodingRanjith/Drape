import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../product.dart';
import '../theme/app_theme.dart';

/// Cinematic brand intro — powerful motion, aura, and logo presence.
class LogoPrepageScreen extends StatefulWidget {
  const LogoPrepageScreen({super.key});

  @override
  State<LogoPrepageScreen> createState() => _LogoPrepageScreenState();
}

class _LogoPrepageScreenState extends State<LogoPrepageScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final AnimationController _orbit;
  late final AnimationController _sheen;

  late final Animation<double> _bloom;
  late final Animation<double> _ringA;
  late final Animation<double> _ringB;
  late final Animation<double> _markScale;
  late final Animation<double> _markFade;
  late final Animation<double> _markTilt;
  late final Animation<double> _markLift;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleRise;
  late final Animation<double> _ruleWidth;
  late final Animation<double> _tagFade;
  late final Animation<double> _tagTrack;
  late final Animation<double> _rays;

  /// Web audioplayers has a Duration cast bug on durationchange events.
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _bloom = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    );
    _ringA = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.04, 0.55, curve: Curves.easeOutCubic),
    );
    _ringB = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
    );
    _rays = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _markScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.42, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.02, 0.52),
      ),
    );
    _markFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );
    _markTilt = Tween<double>(begin: -0.14, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.02, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _markLift = Tween<double>(begin: 36, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.02, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.38, 0.68, curve: Curves.easeOut),
    );
    _titleRise = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.38, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _ruleWidth = Tween<double>(begin: 0, end: 132).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.52, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.62, 0.92, curve: Curves.easeOut),
    );
    _tagTrack = Tween<double>(begin: 4.2, end: 1.4).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.62, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    unawaited(_bootAudioAndMotion());
  }

  Future<void> _bootAudioAndMotion() async {
    unawaited(_playSplashSound());
    if (!mounted) return;
    await _intro.forward();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _pulse.repeat(reverse: true);
    _orbit.repeat();
    _sheen.repeat();
  }

  Future<void> _playSplashSound() async {
    HapticFeedback.lightImpact();
    // Skip on web — audioplayers_web duration callback throws TypeError.
    if (kIsWeb) return;
    try {
      final player = AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.88);
      await player.play(
        AssetSource('brand/splash_chime.mp3', mimeType: 'audio/mpeg'),
      );
    } catch (_) {
      // Autoplay / decode failures should never block the splash UI.
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _orbit.dispose();
    _sheen.dispose();
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(() async {
        try {
          await player.stop();
          await player.dispose();
        } catch (_) {}
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _pulse, _orbit, _sheen]),
        builder: (context, _) {
          final breath = 1 + (_pulse.value * 0.028);
          final glow = 0.12 + (_pulse.value * 0.1) + (_bloom.value * 0.12);
          final sheenWave = math.sin(_sheen.value * math.pi * 2);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Cream stage
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFDFB),
                      Color(0xFFF7F2EC),
                      Color(0xFFE8DFD4),
                    ],
                  ),
                ),
              ),

              // Soft vignette
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.04 * _bloom.value),
                    ],
                  ),
                ),
              ),

              // Gold light rays behind logo
              Opacity(
                opacity: 0.55 * _rays.value,
                child: CustomPaint(
                  painter: _LightRaysPainter(
                    turn: _orbit.value,
                    intensity: 0.35 + _pulse.value * 0.25,
                  ),
                ),
              ),

              // Living terracotta / gold bloom
              Opacity(
                opacity: 0.7 * _bloom.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.08),
                      radius: 0.72 + (_bloom.value * 0.35) + (_pulse.value * 0.04),
                      colors: [
                        AppColors.gold.withValues(alpha: 0.28),
                        AppColors.terracottaSoft.withValues(alpha: 0.45),
                        AppColors.gold.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.28, 0.55, 1],
                    ),
                  ),
                ),
              ),

              // Orbiting spark dust
              CustomPaint(
                painter: _OrbitDustPainter(
                  progress: _orbit.value,
                  pulse: _pulse.value,
                  reveal: Curves.easeOut.transform(
                    ((_intro.value - 0.18) / 0.5).clamp(0.0, 1.0),
                  ),
                ),
              ),

              // Twinkling stars
              CustomPaint(
                painter: _SparkPainter(
                  progress: _sheen.value,
                  reveal: Curves.easeOut.transform(
                    ((_intro.value - 0.2) / 0.55).clamp(0.0, 1.0),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer shockwave ring
                              Opacity(
                                opacity: (1 - _ringA.value) * 0.85,
                                child: Transform.scale(
                                  scale: 0.4 + (_ringA.value * 1.45),
                                  child: Container(
                                    width: 168,
                                    height: 168,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.55,
                                        ),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Second delayed ring
                              Opacity(
                                opacity: (1 - _ringB.value) * 0.55,
                                child: Transform.scale(
                                  scale: 0.5 + (_ringB.value * 1.35),
                                  child: Container(
                                    width: 168,
                                    height: 168,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.terracotta.withValues(
                                          alpha: 0.35,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Steady hairline orbit ring
                              Opacity(
                                opacity: 0.45 * _markFade.value,
                                child: Transform.rotate(
                                  angle: _orbit.value * math.pi * 2,
                                  child: Container(
                                    width: 176,
                                    height: 176,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.28,
                                        ),
                                        width: 0.9,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Aura bloom
                              Transform.scale(
                                scale: (0.75 + _bloom.value * 0.5) * breath,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.terracotta.withValues(
                                          alpha: glow,
                                        ),
                                        blurRadius: 56,
                                        spreadRadius: 6,
                                      ),
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: glow * 0.7,
                                        ),
                                        blurRadius: 90,
                                        spreadRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Rotating shimmer arc
                              Opacity(
                                opacity: 0.7 * _markFade.value,
                                child: Transform.rotate(
                                  angle: _orbit.value * math.pi * 2,
                                  child: CustomPaint(
                                    size: const Size(184, 184),
                                    painter: _ShimmerRingPainter(
                                      progress: _intro.value,
                                    ),
                                  ),
                                ),
                              ),
                              // Logo mark
                              Opacity(
                                opacity: _markFade.value,
                                child: Transform.translate(
                                  offset: Offset(0, _markLift.value),
                                  child: Transform.rotate(
                                    angle: _markTilt.value,
                                    child: Transform.scale(
                                      scale: _markScale.value * breath,
                                      child: _LogoMark(
                                        glow: glow,
                                        sheen: _sheen.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleRise.value),
                            child: _Wordmark(
                              progress: _titleFade.value,
                              sheen: sheenWave,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: _ruleWidth.value,
                          height: 12,
                          child: Opacity(
                            opacity: Curves.easeOut.transform(
                              ((_intro.value - 0.52) / 0.26).clamp(0.0, 1.0),
                            ),
                            child: _BrandRule(pulse: _pulse.value),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _tagFade.value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - _tagFade.value) * 14),
                            child: Column(
                              children: [
                                Text(
                                  MineProduct.tagline.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: _tagTrack.value,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  MineProduct.productLine,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: AppColors.muted.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Diagonal light sweep
              IgnorePointer(
                child: Opacity(
                  opacity: 0.22 * sheenWave.abs().clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      (size.width + 160) * (_sheen.value * 2 - 1) - 80,
                      -40,
                    ),
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 110,
                        height: size.height + 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.65),
                              AppColors.gold.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.4, 0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.glow, required this.sheen});

  final double glow;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    final sweep = (sheen * 2 - 0.3).clamp(0.0, 1.0);

    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18 + glow * 0.4),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.22 + glow * 0.25),
            blurRadius: 40,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/brand/app_icon.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          // Glass bevel
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.9, -1),
                end: const Alignment(0.7, 0.5),
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
          // Moving metal sheen across the M
          Transform.translate(
            offset: Offset((sweep * 160) - 40, 0),
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.45),
                      AppColors.gold.withValues(alpha: 0.35),
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

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress, required this.sheen});

  final double progress;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    final word = MineProduct.appName;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < word.length; i++)
          _Letter(
            letter: word[i],
            index: i,
            total: word.length,
            progress: progress,
            sheen: sheen,
          ),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.index,
    required this.total,
    required this.progress,
    required this.sheen,
  });

  final String letter;
  final int index;
  final int total;
  final double progress;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    final start = index / (total + 2.5);
    final local = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(local);
    final flash = (1 - (sheen - (index * 0.15)).abs()).clamp(0.0, 1.0);

    return Opacity(
      opacity: eased.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 22),
        child: Transform.scale(
          scale: 0.78 + (eased * 0.22),
          child: Text(
            letter,
            style: GoogleFonts.manrope(
              fontSize: 54,
              fontWeight: FontWeight.w700,
              color: Color.lerp(
                AppColors.ink,
                AppColors.gold,
                flash * 0.18,
              ),
              letterSpacing: -1,
              height: 1,
              shadows: [
                Shadow(
                  color: AppColors.gold.withValues(alpha: 0.25 * flash),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRule extends StatelessWidget {
  const _BrandRule({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final diamond = 7.0 + pulse * 1.5;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.gold.withValues(alpha: 0.75),
                AppColors.gold,
                AppColors.gold.withValues(alpha: 0.75),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: diamond,
            height: diamond,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0DCA8), Color(0xFFC49A4A), Color(0xFF8F5A28)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.55 + pulse * 0.2),
                  blurRadius: 10 + pulse * 6,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerRingPainter extends CustomPainter {
  _ShimmerRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.gold.withValues(alpha: 0.0),
          AppColors.gold.withValues(alpha: 0.85 * progress.clamp(0.2, 1)),
          Colors.white.withValues(alpha: 0.7),
          AppColors.terracotta.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 0.68, 0.78, 0.88, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LightRaysPainter extends CustomPainter {
  _LightRaysPainter({required this.turn, required this.intensity});

  final double turn;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final longest = size.longestSide;
    for (var i = 0; i < 10; i++) {
      final a = turn * math.pi * 2 + (i * math.pi / 5);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a - 0.04) * longest,
          center.dy + math.sin(a - 0.04) * longest,
        )
        ..lineTo(
          center.dx + math.cos(a + 0.04) * longest,
          center.dy + math.sin(a + 0.04) * longest,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            longest * 0.7,
            [
              AppColors.gold.withValues(alpha: 0.14 * intensity),
              Colors.transparent,
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter oldDelegate) =>
      oldDelegate.turn != turn || oldDelegate.intensity != intensity;
}

class _OrbitDustPainter extends CustomPainter {
  _OrbitDustPainter({
    required this.progress,
    required this.pulse,
    required this.reveal,
  });

  final double progress;
  final double pulse;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    for (var i = 0; i < 18; i++) {
      final orbit = 70.0 + (i % 5) * 14;
      final a = progress * math.pi * 2 * (i.isEven ? 1 : -0.7) + i * 0.7;
      final x = center.dx + math.cos(a) * orbit;
      final y = center.dy + math.sin(a) * orbit * 0.72;
      final twinkle =
          0.4 + 0.6 * ((math.sin(progress * 8 + i)).abs());
      canvas.drawCircle(
        Offset(x, y),
        1.3 + (i % 3) * 0.5 + pulse * 0.4,
        Paint()
          ..color = (i.isEven ? AppColors.gold : const Color(0xFFE8C89A))
              .withValues(alpha: 0.22 * twinkle * reveal),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDustPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.reveal != reveal;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.progress, required this.reveal});

  final double progress;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final rnd = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 36; i++) {
      final bx = rnd.nextDouble();
      final by = rnd.nextDouble();
      final drift = math.sin((progress + i * 0.13) * math.pi * 2);
      final x = size.width * (0.12 + bx * 0.76) + drift * 12;
      final y = size.height * (0.14 + by * 0.6) + drift * 8;
      final twinkle =
          (0.3 + 0.7 * ((math.sin((progress * 5 + i) * math.pi)).abs())) *
              reveal;
      paint.color = (i.isEven ? AppColors.gold : AppColors.terracotta)
          .withValues(alpha: 0.2 * twinkle);
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.55, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.reveal != reveal;
}
