import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../product.dart';
import '../theme/app_theme.dart';

/// Cinematic brand intro with motion + sound.
class LogoPrepageScreen extends StatefulWidget {
  const LogoPrepageScreen({super.key});

  @override
  State<LogoPrepageScreen> createState() => _LogoPrepageScreenState();
}

class _LogoPrepageScreenState extends State<LogoPrepageScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final AnimationController _shimmer;

  late final Animation<double> _bloom;
  late final Animation<double> _ring;
  late final Animation<double> _markScale;
  late final Animation<double> _markFade;
  late final Animation<double> _markTilt;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleRise;
  late final Animation<double> _ruleWidth;
  late final Animation<double> _tagFade;
  late final Animation<double> _tagTrack;

  final _player = AudioPlayer();

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
      duration: const Duration(milliseconds: 2200),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _bloom = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _ring = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.08, 0.62, curve: Curves.easeOutCubic),
    );
    _markScale = Tween<double>(begin: 0.62, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.05, 0.48, curve: Curves.easeOutBack),
      ),
    );
    _markFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOut),
    );
    _markTilt = Tween<double>(begin: -0.08, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.05, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.62, curve: Curves.easeOut),
    );
    _titleRise = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.34, 0.68, curve: Curves.easeOutCubic),
      ),
    );
    _ruleWidth = Tween<double>(begin: 0, end: 120).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.48, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.58, 0.86, curve: Curves.easeOut),
    );
    _tagTrack = Tween<double>(begin: 3.2, end: 1.4).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.58, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    unawaited(_bootAudioAndMotion());
  }

  Future<void> _bootAudioAndMotion() async {
    unawaited(_playSplashSound());

    if (!mounted) return;
    await _intro.forward();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    _pulse.repeat(reverse: true);
    _shimmer.repeat();
  }

  Future<void> _playSplashSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.88);
      await _player.play(
        AssetSource('brand/splash_chime.mp3', mimeType: 'audio/mpeg'),
      );
      HapticFeedback.lightImpact();
    } catch (_) {
      // Web autoplay / decode failures should never block the splash UI.
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _shimmer.dispose();
    unawaited(_player.stop());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _pulse, _shimmer]),
        builder: (context, _) {
          final pulse = 1 + (_pulse.value * 0.018);
          final glow = 0.10 + (_pulse.value * 0.06) + (_bloom.value * 0.08);

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFCF8),
                      AppColors.parchment,
                      Color(0xFFEDE6DD),
                    ],
                  ),
                ),
              ),
              // Soft living light wash
              Opacity(
                opacity: 0.55 * _bloom.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.12),
                      radius: 0.85 + (_bloom.value * 0.25),
                      colors: [
                        AppColors.terracottaSoft.withValues(alpha: 0.55),
                        AppColors.gold.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              // Floating spark dust
              CustomPaint(
                painter: _SparkPainter(
                  progress: _shimmer.value,
                  reveal: Curves.easeOut.transform(
                    ((_intro.value - 0.25) / 0.55).clamp(0.0, 1.0),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 190,
                          height: 190,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Expanding gold ring
                              Opacity(
                                opacity: (1 - _ring.value) * 0.7,
                                child: Transform.scale(
                                  scale: 0.55 + (_ring.value * 1.15),
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.45,
                                        ),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Soft bloom behind mark
                              Transform.scale(
                                scale: 0.7 + (_bloom.value * 0.55),
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.terracotta.withValues(
                                          alpha: glow,
                                        ),
                                        blurRadius: 48,
                                        spreadRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: glow * 0.55,
                                        ),
                                        blurRadius: 72,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Rotating soft shimmer arc
                              Opacity(
                                opacity: 0.55 * _markFade.value,
                                child: Transform.rotate(
                                  angle: _shimmer.value * math.pi * 2,
                                  child: CustomPaint(
                                    size: const Size(168, 168),
                                    painter: _ShimmerRingPainter(
                                      progress: _intro.value,
                                    ),
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: _markFade.value,
                                child: Transform.rotate(
                                  angle: _markTilt.value,
                                  child: Transform.scale(
                                    scale: _markScale.value * pulse,
                                    child: _LogoMark(glow: glow),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleRise.value),
                            child: _Wordmark(progress: _titleFade.value),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: _ruleWidth.value,
                          height: 10,
                          child: Opacity(
                            opacity: Curves.easeOut.transform(
                              ((_intro.value - 0.48) / 0.24).clamp(0.0, 1.0),
                            ),
                            child: const _BrandRule(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: _tagFade.value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - _tagFade.value) * 10),
                            child: Column(
                              children: [
                                Text(
                                  MineProduct.tagline,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: _tagTrack.value,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  MineProduct.productLine,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: AppColors.muted.withValues(
                                      alpha: 0.85,
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
              // Subtle sheen sweep across the whole stage
              IgnorePointer(
                child: Opacity(
                  opacity: 0.18 * math.sin(_shimmer.value * math.pi).clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(
                      (MediaQuery.sizeOf(context).width + 120) *
                              (_shimmer.value * 2 - 1) -
                          60,
                      0,
                    ),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
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
  const _LogoMark({required this.glow});

  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16 + glow * 0.35),
            blurRadius: 28,
            offset: const Offset(0, 16),
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
          // Glass highlight
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -1),
                end: const Alignment(0.6, 0.4),
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.08),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress});

  final double progress;

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
  });

  final String letter;
  final int index;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final start = index / (total + 2);
    final local = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 16),
        child: Transform.scale(
          scale: 0.92 + (eased * 0.08),
          child: Text(
            letter,
            style: GoogleFonts.playfairDisplay(
              fontSize: 50,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: -0.8,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRule extends StatelessWidget {
  const _BrandRule();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(height: 1, color: AppColors.gold.withValues(alpha: 0.55)),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
          transform: Matrix4.rotationZ(0.785398),
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
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.gold.withValues(alpha: 0.0),
          AppColors.gold.withValues(alpha: 0.75 * progress.clamp(0.2, 1)),
          Colors.white.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 0.72, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
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

    for (var i = 0; i < 28; i++) {
      final bx = rnd.nextDouble();
      final by = rnd.nextDouble();
      final drift = math.sin((progress + i * 0.13) * math.pi * 2);
      final x = size.width * (0.15 + bx * 0.7) + drift * 10;
      final y = size.height * (0.18 + by * 0.55) + drift * 6;
      final twinkle =
          (0.35 + 0.65 * ((math.sin((progress * 4 + i) * math.pi)).abs())) *
          reveal;
      paint.color = (i.isEven ? AppColors.gold : AppColors.terracotta)
          .withValues(alpha: 0.18 * twinkle);
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.reveal != reveal;
}
