import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class SplashWalkthroughScreen extends StatefulWidget {
  const SplashWalkthroughScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashWalkthroughScreen> createState() =>
      _SplashWalkthroughScreenState();
}

class _SplashWalkthroughScreenState extends State<SplashWalkthroughScreen> {
  final _pages = PageController();
  var _index = 0;

  static const _slides = [
    _Slide(
      image: 'assets/walkthrough/style.png',
      title: 'Find Your Unique Style',
      body:
          'Discover your authentic fashion identity with personalized recommendations and exclusive collections.',
      wash: Color(0xFF7A1848),
    ),
    _Slide(
      image: 'assets/walkthrough/closet.png',
      title: 'Your Closet, Elevated',
      body:
          'Photograph every piece once. Drape keeps your wardrobe organized, ready, and easy to mix into beautiful looks.',
      wash: Color(0xFF1F6F6A),
    ),
    _Slide(
      image: 'assets/walkthrough/today.png',
      title: 'What To Wear Today',
      body:
          'Wake up to a complete look assembled from your own closet — no more morning guesswork.',
      wash: Color(0xFFC45C26),
    ),
    _Slide(
      image: 'assets/walkthrough/week.png',
      title: 'Styled For Every Day',
      body:
          'Plan outfits across the week and your calendar, so every moment feels intentional and nothing repeats too soon.',
      wash: Color(0xFF5C3D24),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _pages.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index >= _slides.length - 1) {
      widget.onFinished();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: PageView.builder(
        controller: _pages,
        itemCount: _slides.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return _WalkthroughPage(
            slide: _slides[i],
            index: i,
            count: _slides.length,
            onSkip: widget.onFinished,
            onNext: _goNext,
          );
        },
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.body,
    required this.wash,
  });

  final String image;
  final String title;
  final String body;
  final Color wash;
}

class _WalkthroughPage extends StatelessWidget {
  const _WalkthroughPage({
    required this.slide,
    required this.index,
    required this.count,
    required this.onSkip,
    required this.onNext,
  });

  final _Slide slide;
  final int index;
  final int count;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final last = index == count - 1;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: slide.wash,
          child: Image.asset(
            slide.image,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.32),
            filterQuality: FilterQuality.high,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x00000000),
                Color(0x59000000),
                Color(0xCC111111),
              ],
              stops: [0, 0.28, 0.58, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            padding: EdgeInsets.fromLTRB(28, 32, 28, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A8178),
                  ),
                ),
                const SizedBox(height: 28),
                _Dots(index: index, count: count),
                const SizedBox(height: 22),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: onNext,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          child: Text(
                            last ? 'Start' : 'Next',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? AppColors.ink : const Color(0xFFD8D0C8),
            ),
          ),
          if (i != count - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
