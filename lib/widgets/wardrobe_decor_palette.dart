import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe_decor.dart';
import '../theme/app_theme.dart';
import 'wardrobe_decor_sticker.dart';

/// Bottom tray of searchable animated GIF stickers (with backgrounds).
class WardrobeDecorPalette extends StatefulWidget {
  const WardrobeDecorPalette({
    super.key,
    required this.onDone,
  });

  final VoidCallback onDone;

  @override
  State<WardrobeDecorPalette> createState() => _WardrobeDecorPaletteState();
}

class _WardrobeDecorPaletteState extends State<WardrobeDecorPalette> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchWardrobeDecor(_query);

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
                      'Customize with GIFs',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Done'),
                  ),
                ],
              ),
              Text(
                'Search, then drag a GIF onto any shelf',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search cute, plant, cat, light…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.85),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD4B896)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD4B896)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 108,
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'No GIFs match “$_query”',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final kind = results[index];
                          return LongPressDraggable<String>(
                            data: kind.id,
                            feedback: Material(
                              color: Colors.transparent,
                              child: WardrobeDecorSticker(
                                kind: kind,
                                size: 76,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: WardrobeDecorSticker(
                                kind: kind,
                                size: 58,
                                showLabel: true,
                              ),
                            ),
                            child: WardrobeDecorSticker(
                              kind: kind,
                              size: 58,
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
