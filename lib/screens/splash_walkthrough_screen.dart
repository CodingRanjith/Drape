import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../product.dart';
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
          'Photograph every piece once. Mine keeps your wardrobe organized, ready, and easy to mix into beautiful looks.',
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
            onBack: i == 0
                ? null
                : () => _pages.previousPage(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  ),
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
    this.onBack,
  });

  final _Slide slide;
  final int index;
  final int count;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback? onBack;

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
            alignment: const Alignment(0, -0.2),
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => ColoredBox(color: slide.wash),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x55000000),
                Color(0x14000000),
                Color(0x99000000),
              ],
              stops: [0, 0.42, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 12, 28, 16 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    Text(
                      MineProduct.appName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  slide.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xE6FFFFFF),
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
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.white,
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
                              color: AppColors.ink,
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
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? Colors.white : const Color(0x66FFFFFF),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (i != count - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
