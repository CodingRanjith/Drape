import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe_decor.dart';

/// Looping gif-like sticker for wardrobe shelves / palette.
class WardrobeDecorSticker extends StatefulWidget {
  const WardrobeDecorSticker({
    super.key,
    required this.kind,
    this.size = 64,
    this.showLabel = false,
    this.onLongPress,
  });

  final WardrobeDecorKind kind;
  final double size;
  final bool showLabel;
  final VoidCallback? onLongPress;

  @override
  State<WardrobeDecorSticker> createState() => _WardrobeDecorStickerState();
}

class _WardrobeDecorStickerState extends State<WardrobeDecorSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 900 + (widget.kind.id.hashCode.abs() % 500),
      ),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          final bob = math.sin(t * math.pi) * 3.5;
          final sway = math.sin(t * math.pi * 2) * 0.04;
          return Transform.translate(
            offset: Offset(0, -bob),
            child: Transform.rotate(
              angle: sway,
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF6EA),
                    Color(0xFFE8D5B0),
                    Color(0xFFD4A86A),
                  ],
                ),
                border: Border.all(color: const Color(0xFF6B3F1A), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.kind.emoji,
                style: TextStyle(fontSize: widget.size * 0.48),
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              Text(
                widget.kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A2414),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
