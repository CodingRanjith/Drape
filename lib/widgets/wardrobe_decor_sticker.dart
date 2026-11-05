import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe_decor.dart';

/// Looping animated GIF sticker (with background) for wardrobe shelves / palette.
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
        milliseconds: 1100 + (widget.kind.id.hashCode.abs() % 600),
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
          final bob = math.sin(t * math.pi) * 2.8;
          final sway = math.sin(t * math.pi * 2) * 0.03;
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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6B3F1A), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Soft paper BG behind the GIF so empty/transparent frames still read.
                  const ColoredBox(color: Color(0xFFFFF6EA)),
                  Image.network(
                    widget.kind.gifUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        widget.kind.emoji,
                        style: TextStyle(fontSize: widget.size * 0.45),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: Text(
                          widget.kind.emoji,
                          style: TextStyle(fontSize: widget.size * 0.4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: widget.size + 8,
                child: Text(
                  widget.kind.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A2414),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
