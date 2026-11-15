import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../product.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/mine_logo_mark.dart';

/// Full-app intro after a new profile is created.
///
/// Temporary: plays a YouTube stand-in until local EN/TA films are ready.
/// Local assets (when present) still win over YouTube.
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({super.key});

  static const assetPathEn = 'assets/intro/mine_app_intro_en.mp4';
  static const assetPathTa = 'assets/intro/mine_app_intro_ta.mp4';

  /// Temporary stand-in: https://youtu.be/0gcBg9gv8gk
  static const tempYoutubeId = '0gcBg9gv8gk';

  static String assetFor(String lang) =>
      lang == 'ta' ? assetPathTa : assetPathEn;

  static String youtubeEmbedSrc(String lang) {
    final cc = lang == 'ta' ? 'ta' : 'en';
    // mute=1 is required for reliable autoplay inside Android WebView.
    return 'https://www.youtube.com/embed/$tempYoutubeId'
        '?autoplay=1&mute=1&playsinline=1&rel=0&modestbranding=1'
        '&controls=1&fs=1&cc_lang_pref=$cc&enablejsapi=1';
  }

  /// Full-bleed 16:9 iframe page — avoids YouTube chrome filling the whole phone.
  static String youtubeEmbedHtml(String lang) {
    final src = youtubeEmbedSrc(lang);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
<style>
  * { box-sizing: border-box; }
  html, body {
    margin: 0; padding: 0; width: 100%; height: 100%;
    background: #14110F; overflow: hidden;
  }
  .frame {
    position: absolute; inset: 0;
    width: 100%; height: 100%;
  }
  iframe {
    position: absolute; inset: 0;
    width: 100%; height: 100%;
    border: 0; background: #000;
  }
</style>
</head>
<body>
  <div class="frame">
    <iframe
      src="$src"
      title="Mine intro"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"
    ></iframe>
  </div>
</body>
</html>
''';
  }

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _fileController;
  WebViewController? _webController;
  var _mode = _IntroMode.loading; // file | youtube | failed
  var _finishing = false;
  var _loading = false;
  var _lang = 'en';
  var _started = false;
  var _webReady = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
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
    _webController = null;
    _webReady = false;
  }

  Future<void> _boot(String lang) async {
    setState(() {
      _loading = true;
      _mode = _IntroMode.loading;
      _webReady = false;
    });
    await _disposePlayers();

    // Prefer local film when the user has dropped it in.
    final localOk = await _tryLocal(lang);
    if (localOk) return;

    // Temporary YouTube stand-in in a fixed 16:9 frame.
    await _tryYoutube(lang);
  }

  Future<bool> _tryLocal(String lang) async {
    try {
      final c = VideoPlayerController.asset(IntroVideoScreen.assetFor(lang));
      _fileController = c;
      await c.initialize();
      await c.setLooping(false);
      c.addListener(_onFileTick);
      await c.play();
      if (!mounted) return true;
      setState(() {
        _lang = lang;
        _mode = _IntroMode.file;
        _loading = false;
      });
      return true;
    } catch (e) {
      debugPrint('Local intro missing ($lang): $e');
      await _fileController?.dispose();
      _fileController = null;
      return false;
    }
  }

  Future<void> _configureAndroid(WebViewController controller) async {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }
  }

  Future<void> _tryYoutube(String lang) async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFF14110F));
      await _configureAndroid(controller);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _webReady = true;
              _loading = false;
            });
          },
          onWebResourceError: (error) {
            debugPrint(
              'YouTube intro resource error: ${error.errorCode} ${error.description}',
            );
            // Ignore subframe noise; only fail the main document.
            if (error.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() {
              _mode = _IntroMode.failed;
              _loading = false;
            });
          },
        ),
      );
      await controller.loadHtmlString(
        IntroVideoScreen.youtubeEmbedHtml(lang),
        baseUrl: 'https://www.youtube.com',
      );
      _webController = controller;
      if (!mounted) return;
      setState(() {
        _lang = lang;
        _mode = _IntroMode.youtube;
        // Keep spinner until page finishes (or timeout below).
      });
      // If onPageFinished never fires (some WebViews), still show the frame.
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted || _mode != _IntroMode.youtube) return;
        if (_loading) {
          setState(() {
            _loading = false;
            _webReady = true;
          });
        }
      });
    } catch (e, st) {
      debugPrint('YouTube intro failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _lang = lang;
        _mode = _IntroMode.failed;
        _loading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final file = _fileController;
    final web = _webController;
    final isTa = _lang == 'ta';
    final showFile =
        _mode == _IntroMode.file && file != null && file.value.isInitialized;
    final showYoutube = _mode == _IntroMode.youtube && web != null;
    final failed = _mode == _IntroMode.failed;

    return Scaffold(
      backgroundColor: const Color(0xFF14110F),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A221C), Color(0xFF14110F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const MineLogoMark(size: 44, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MineProduct.appName,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
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
              const SizedBox(height: 18),
              // Fixed 16:9 stage for file or YouTube iframe.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (showFile)
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: file.value.size.width,
                                height: file.value.size.height,
                                child: VideoPlayer(file),
                              ),
                            )
                          else if (showYoutube)
                            WebViewWidget(controller: web)
                          else if (failed)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  isTa
                                      ? 'வீடியோ ஏற்ற முடியவில்லை.'
                                      : 'Could not load the intro video.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.terracotta,
                              ),
                            ),
                          if (_loading && showYoutube && !_webReady)
                            const ColoredBox(
                              color: Color(0xAA14110F),
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
              if (showFile) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProgressBar(controller: file),
                ),
              ],
              if (showYoutube) ...[
                const SizedBox(height: 10),
                Text(
                  isTa
                      ? 'தற்காலிக YouTube அறிமுகம் · 16:9'
                      : 'Temporary YouTube intro · 16:9',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
              ],
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (failed || (!showFile && !showYoutube && !_loading))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            failed
                                ? (isTa
                                    ? 'தொடர்ந்து Mine-ஐ பயன்படுத்தலாம்.'
                                    : 'You can continue into Mine.')
                                : (isTa
                                    ? 'உங்கள் Mine அறிமுகம் ஏற்றப்படுகிறது…'
                                    : 'Loading your Mine intro…'),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      if (isTa) ...[
                        const _Beat(
                          title: 'பிரச்சனை',
                          body: 'அலமாரி குழப்பம். அதே உடைகள். வீணான காலை.',
                        ),
                        const _Beat(
                          title: 'தீர்வு',
                          body: 'உடைகளை பதிவு செய். Mine இன்றைய லுக் தரும்.',
                        ),
                        const _Beat(
                          title: 'பயன்படுத்து',
                          body: 'Shuffle, Save, வாரம் பிளான் — எளிதாக உடுத்து.',
                        ),
                      ] else ...[
                        const _Beat(
                          title: 'Problem',
                          body: 'Closet chaos. Same outfits. Wasted mornings.',
                        ),
                        const _Beat(
                          title: 'Solution',
                          body:
                              'Upload your clothes. Mine builds today’s look.',
                        ),
                        const _Beat(
                          title: 'Use it',
                          body:
                              'Shuffle, save, plan the week, and dress with ease.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: Text(
                        isTa ? 'தவிர்' : 'Skip',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _finishing ? null : _finish,
                      child: Text(
                        failed
                            ? (isTa ? 'தொடர்' : 'Continue')
                            : (isTa ? 'தொடங்கு' : 'Get started'),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _IntroMode { loading, file, youtube, failed }

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
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
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
            color: Colors.white,
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
            backgroundColor: Colors.white24,
            color: AppColors.terracotta,
          ),
        );
      },
    );
  }
}

class _Beat extends StatelessWidget {
  const _Beat({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.terracotta,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  body,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                    height: 1.35,
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
