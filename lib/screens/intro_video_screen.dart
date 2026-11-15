import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../product.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/mine_logo_mark.dart';

/// Full-app intro after a new profile is created.
/// Plays local EN / TA films from assets (no YouTube).
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  static const assetPathEn = 'assets/intro/mine_app_intro_en.mp4';
  static const assetPathTa = 'assets/intro/mine_app_intro_ta.mp4';

  /// Prefer language film; Tamil falls back to English if TA file is missing.
  static List<String> assetCandidates(String lang) => lang == 'ta'
      ? const [assetPathTa, assetPathEn]
      : const [assetPathEn];

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _fileController;
  var _mode = _IntroMode.loading;
  var _finishing = false;
  var _loading = false;
  var _lang = 'en';
  var _started = false;

  late final AnimationController _enter;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _videoFade;
  late final Animation<Offset> _videoSlide;
  late final Animation<double> _stepsFade;
  late final Animation<Offset> _stepsSlide;
  late final Animation<double> _ctaFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _videoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.55, curve: Curves.easeOutCubic),
    );
    _videoSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.18, 0.58, curve: Curves.easeOutCubic),
      ),
    );
    _stepsFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.4, 0.78, curve: Curves.easeOutCubic),
    );
    _stepsSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.4, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _ctaFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
    );
    unawaited(_enter.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _lang = context.read<MineState>().profile.introVideoLang == 'ta'
        ? 'ta'
        : 'en';
    unawaited(_boot(_lang));
  }

  Future<void> _disposePlayers() async {
    final file = _fileController;
    _fileController = null;
    file?.removeListener(_onFileTick);
    await file?.pause();
    await file?.dispose();
  }

  Future<void> _boot(String lang) async {
    setState(() {
      _loading = true;
      _mode = _IntroMode.loading;
    });
    await _disposePlayers();

    final localOk = await _tryLocal(lang);
    if (localOk) return;

    if (!mounted) return;
    setState(() {
      _lang = lang;
      _mode = _IntroMode.failed;
      _loading = false;
    });
  }

  Future<bool> _tryLocal(String lang) async {
    for (final path in IntroVideoScreen.assetCandidates(lang)) {
      try {
        // Confirm asset is registered in pubspec / AssetManifest.
        await rootBundle.load(path);
        final c = VideoPlayerController.asset(
          path,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _fileController = c;
        await c.initialize();
        if (!c.value.isInitialized || c.value.hasError) {
          throw StateError(c.value.errorDescription ?? 'init failed');
        }
        await c.setLooping(false);
        await c.setVolume(1);
        c.addListener(_onFileTick);
        await c.play();
        if (!mounted) return true;
        setState(() {
          _lang = lang;
          _mode = _IntroMode.file;
          _loading = false;
        });
        debugPrint('Intro local video playing: $path');
        return true;
      } catch (e) {
        debugPrint('Local intro failed ($path): $e');
        await _fileController?.dispose();
        _fileController = null;
      }
    }
    return false;
  }

  Future<void> _setLang(String lang) async {
    if (_finishing || lang == _lang) return;
    await context.read<MineState>().setIntroVideoLang(lang);
    if (!mounted) return;
    await _boot(lang);
  }

  void _onFileTick() {
    final c = _fileController;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;
    if (v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 400)) {
      unawaited(_finish());
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    if (!mounted) return;
    await context.read<MineState>().completeIntroVideo();
  }

  @override
  void dispose() {
    _enter.dispose();
    _fileController?.removeListener(_onFileTick);
    unawaited(_disposePlayers());
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  /// UI copy stays English; EN|தமிழ் only switches the video.
  static const _steps = <({String title, String body, IconData icon})>[
    (
      title: 'Problem',
      body: 'Closet chaos. Same outfits. Wasted mornings.',
      icon: Icons.weekend_outlined,
    ),
    (
      title: 'Solution',
      body: 'Upload your clothes. Mine builds today’s look.',
      icon: Icons.auto_awesome_outlined,
    ),
    (
      title: 'Use it',
      body: 'Shuffle, save, plan the week, and dress with ease.',
      icon: Icons.checkroom_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final file = _fileController;
    final showFile =
        _mode == _IntroMode.file && file != null && file.value.isInitialized;
    final failed = _mode == _IntroMode.failed;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBF7),
              AppColors.parchment,
              AppColors.terracottaSoft,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top: logo + brand + lang
              FadeTransition(
                opacity: _logoFade,
                child: SlideTransition(
                  position: _logoSlide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                    child: Row(
                      children: [
                        const MineLogoMark(size: 52, radius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MineProduct.appName,
                                style: GoogleFonts.manrope(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  color: AppColors.ink,
                                  height: 1.05,
                                ),
                              ),
                              Text(
                                MineProduct.tagline,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.terracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _LangToggle(
                          lang: _lang,
                          enabled: !_finishing && !_loading,
                          onChanged: _setLang,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Center video 16:9
              FadeTransition(
                opacity: _videoFade,
                child: SlideTransition(
                  position: _videoSlide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.terracotta
                                      .withValues(alpha: 0.14),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: ColoredBox(
                                color: AppColors.ink,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (showFile)
                                      ColoredBox(
                                        color: Colors.black,
                                        child: Center(
                                          child: AspectRatio(
                                            aspectRatio: file.value.aspectRatio ==
                                                    0
                                                ? 16 / 9
                                                : file.value.aspectRatio,
                                            child: VideoPlayer(file),
                                          ),
                                        ),
                                      )
                                    else if (failed)
                                      ColoredBox(
                                        color: AppColors.terracottaSoft,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Text(
                                              'Could not load the intro video.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.manrope(
                                                color: AppColors.ink,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      const ColoredBox(
                                        color: AppColors.terracottaSoft,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.terracotta,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showFile) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _ProgressBar(controller: file),
                ),
              ],
              const SizedBox(height: 8),
              // Steps below video
              Expanded(
                child: FadeTransition(
                  opacity: _stepsFade,
                  child: SlideTransition(
                    position: _stepsSlide,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'How it works',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < _steps.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _StepCard(
                              index: i + 1,
                              title: _steps[i].title,
                              body: _steps[i].body,
                              icon: _steps[i].icon,
                              delay: i,
                              parent: _enter,
                            ),
                          ],
                          if (failed) ...[
                            const SizedBox(height: 14),
                            Text(
                              'You can continue into Mine.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // CTA
              FadeTransition(
                opacity: _ctaFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _finishing ? null : _finish,
                        child: Text(
                          'Skip',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _finishing ? null : _finish,
                        child: Text(
                          failed ? 'Continue' : 'Get started',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
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
    );
  }
}

enum _IntroMode { loading, file, failed }

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.body,
    required this.icon,
    required this.delay,
    required this.parent,
  });

  final int index;
  final String title;
  final String body;
  final IconData icon;
  final int delay;
  final AnimationController parent;

  @override
  Widget build(BuildContext context) {
    final start = 0.42 + delay * 0.1;
    final end = (start + 0.28).clamp(0.0, 1.0);
    final fade = CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.terracottaSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.terracotta, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$index',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.terracotta,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
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

class _LangToggle extends StatelessWidget {
  const _LangToggle({
    required this.lang,
    required this.enabled,
    required this.onChanged,
  });

  final String lang;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip('EN', 'en', lang == 'en'),
              _chip('தமிழ்', 'ta', lang == 'ta'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value, bool selected) {
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.terracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        final total = value.duration.inMilliseconds;
        final pos = value.position.inMilliseconds;
        final t = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: t,
            minHeight: 4,
            backgroundColor: AppColors.clay.withValues(alpha: 0.45),
            color: AppColors.terracotta,
          ),
        );
      },
    );
  }
}
