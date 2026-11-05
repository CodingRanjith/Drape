import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/common.dart';
import '../widgets/page_background.dart';

/// Plain full-outfit view: every piece as one stacked image list.
class OutfitFullViewScreen extends StatelessWidget {
  const OutfitFullViewScreen({
    super.key,
    required this.pieces,
    required this.date,
    this.initialIndex = 0,
  });

  final List<Garment> pieces;
  final DateTime date;

  /// Kept for call-site compatibility; unused in the single stacked view.
  final int initialIndex;

  static const _order = [
    GarmentCategory.dress,
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outerwear,
    GarmentCategory.shoes,
    GarmentCategory.accessory,
  ];

  List<Garment> get _ordered {
    final list = List<Garment>.of(pieces);
    list.sort((a, b) {
      final ai = _order.indexOf(a.category);
      final bi = _order.indexOf(b.category);
      final aRank = ai < 0 ? 99 : ai;
      final bRank = bi < 0 ? 99 : bi;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: const AppBackIcon(),
          title: Text(DateFormat('EEEE d MMM').format(date)),
        ),
        body: ordered.isEmpty
            ? Center(
                child: Text(
                  'No pieces in this look',
                  style: GoogleFonts.manrope(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: ordered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final g = ordered[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        g.typeLabel.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: AppColors.terracotta,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: PhotoTile(
                            garment: g,
                            radius: 22,
                            showName: false,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
