import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe_decor.dart';
import '../theme/app_theme.dart';
import 'wardrobe_decor_sticker.dart';

/// Bottom tray of drag-able gif stickers while customizing the wardrobe.
class WardrobeDecorPalette extends StatelessWidget {
  const WardrobeDecorPalette({
    super.key,
    required this.onDone,
  });

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2FFF6EA),
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Customize your wardrobe',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ],
              ),
              Text(
                'Drag a gif onto any shelf row',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wardrobeDecorCatalog.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final kind = wardrobeDecorCatalog[index];
                    return LongPressDraggable<String>(
                      data: kind.id,
                      feedback: Material(
                        color: Colors.transparent,
                        child: WardrobeDecorSticker(
                          kind: kind,
                          size: 72,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: WardrobeDecorSticker(
                          kind: kind,
                          size: 56,
                          showLabel: true,
                        ),
                      ),
                      child: WardrobeDecorSticker(
                        kind: kind,
                        size: 56,
                        showLabel: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
