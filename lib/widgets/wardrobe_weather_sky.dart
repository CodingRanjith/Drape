import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../services/live_weather.dart';

/// Outdoor sky above the wardrobe — looping clear weather video + live label.
class WardrobeWeatherSky extends StatefulWidget {
  const WardrobeWeatherSky({super.key, this.height = 148});

  final double height;

  @override
  State<WardrobeWeatherSky> createState() => _WardrobeWeatherSkyState();
}

class _WardrobeWeatherSkyState extends State<WardrobeWeatherSky> {
  LiveWeatherSnapshot? _snap;
  var _loading = true;
  WeatherSkyKind? _playingKind;
  VideoPlayerController? _video;
  var _videoReady = false;

  static const _assets = {
    WeatherSkyKind.sunny: 'assets/sky/sunny.mp4',
    WeatherSkyKind.cloudy: 'assets/sky/cloudy.mp4',
    WeatherSkyKind.rainy: 'assets/sky/rainy.mp4',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    try {
      final snap = await LiveWeather.instance.load(force: force);
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loading = false;
      });
      await _ensureVideo(snap.kind);
    } catch (_) {
      if (!mounted) return;
      const fallback = LiveWeatherSnapshot(
        kind: WeatherSkyKind.cloudy,
        temperatureC: 28,
        label: 'Overcast',
        placeName: 'Nearby',
        isDay: true,
        weatherCode: 3,
      );
      setState(() {
        _snap = fallback;
        _loading = false;
      });
      await _ensureVideo(fallback.kind);
    }
  }

  Future<void> _ensureVideo(WeatherSkyKind kind) async {
    if (_playingKind == kind && _video != null) return;
    final asset = _assets[kind]!;
    final next = VideoPlayerController.asset(asset);
    try {
      await next.initialize();
      await next.setLooping(true);
      await next.setVolume(0);
      await next.play();
      final old = _video;
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _video = next;
        _playingKind = kind;
        _videoReady = true;
      });
      await old?.dispose();
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(() {
        _videoReady = false;
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final kind = snap?.kind ?? WeatherSkyKind.cloudy;
    final isDay = snap?.isDay ?? true;
    final topInset = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final label = _labelColor(kind, isDay);
    final fallbackColors = _skyColors(kind, isDay);

    return SizedBox(
      height: widget.height + topInset,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fallback wash while video boots / if decode fails
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fallbackColors,
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),

            // Clear looping weather video
            if (_videoReady && _video != null)
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _video!.value.size.width,
                        height: _video!.value.size.height,
                        child: VideoPlayer(_video!),
                      ),
                    ),
                    if (!isDay)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.42),
                      ),
                  ],
                ),
              ),

            // Soft horizon blend into the room
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFFD2B996).withValues(alpha: 0.35),
                        const Color(0xFFB8956E).withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Light vignette for depth
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.16),
                    ],
                    stops: const [0.55, 1],
                  ),
                ),
              ),
            ),

            // Place / temp
            Positioned(
              left: 18,
              right: 18,
              top: topInset + 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading
                              ? 'Reading the sky…'
                              : (snap?.placeName ?? 'Nearby'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.1,
                            letterSpacing: -0.4,
                            color: label,
                            shadows: [
                              Shadow(
                                blurRadius: 14,
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loading
                              ? 'Live weather'
                              : '${snap?.label ?? ''}  ·  ${snap?.tempLabel ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: label.withValues(alpha: 0.95),
                            shadows: [
                              Shadow(
                                blurRadius: 12,
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.black.withValues(alpha: isDay ? 0.22 : 0.35),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() => _loading = true);
                        _load(force: true);
                      },
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.refresh_rounded,
                          color: label,
                          size: 19,
                        ),
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

  Color _labelColor(WeatherSkyKind kind, bool isDay) {
    if (!isDay) return const Color(0xFFF5F7FA);
    if (kind == WeatherSkyKind.rainy) return const Color(0xFFF3F6F9);
    return const Color(0xFF142033);
  }

  List<Color> _skyColors(WeatherSkyKind kind, bool isDay) {
    switch (kind) {
      case WeatherSkyKind.sunny:
        return isDay
            ? const [Color(0xFF3FA0EF), Color(0xFF8FCBFF), Color(0xFFFFE6B2)]
            : const [Color(0xFF050E1C), Color(0xFF1A2C48), Color(0xFF3D3558)];
      case WeatherSkyKind.cloudy:
        return isDay
            ? const [Color(0xFF6D8296), Color(0xFFA7B6C2), Color(0xFFDDE3E8)]
            : const [Color(0xFF0C1218), Color(0xFF1B242E), Color(0xFF4A5460)];
      case WeatherSkyKind.rainy:
        return isDay
            ? const [Color(0xFF314556), Color(0xFF5A7082), Color(0xFF8FA3B0)]
            : const [Color(0xFF070B10), Color(0xFF141C24), Color(0xFF3A4652)];
    }
  }
}
