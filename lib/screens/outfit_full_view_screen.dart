import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';
import '../widgets/page_background.dart';

/// Centered zoom of one outfit piece, with a circle strip to switch pieces.
class OutfitFullViewScreen extends StatefulWidget {
  const OutfitFullViewScreen({
    super.key,
    required this.pieces,
    required this.date,
    this.initialIndex = 0,
  });

  final List<Garment> pieces;
  final DateTime date;
  final int initialIndex;

  @override
  State<OutfitFullViewScreen> createState() => _OutfitFullViewScreenState();
}

class _OutfitFullViewScreenState extends State<OutfitFullViewScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.pieces.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.pieces.length - 1);
  }

  Garment? get _selected =>
      widget.pieces.isEmpty ? null : widget.pieces[_index];

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const AppBackIcon(),
          title: Text(DateFormat('EEEE d MMM').format(widget.date)),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Center(
                    child: selected == null
                        ? Text(
                            'No pieces in this look',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: PhotoTile(
                                  garment: selected,
                                  radius: 28,
                                  showName: true,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    children: [
                      Text(
                        selected.typeLabel.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.terracotta,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.pieces.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.pieces.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final g = widget.pieces[i];
                        final active = i == _index;
                        final photo = garmentImageProvider(g.imagePath);
                        return GestureDetector(
                          onTap: () => setState(() => _index = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active
                                    ? AppColors.terracotta
                                    : AppColors.line,
                                width: active ? 3 : 1.5,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: AppColors.terracotta
                                            .withValues(alpha: 0.28),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: photo != null
                                  ? Image(image: photo, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: g.primaryColor,
                                      child: Icon(
                                        g.category.icon,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
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