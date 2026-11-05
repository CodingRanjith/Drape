import 'wardrobe.dart';

/// Gold and silver pieces live in the two bottom drawers, not on clothing shelves.
class Jewelry {
  Jewelry._();

  static const goldShelf = 'jewel:gold';
  static const silverShelf = 'jewel:silver';

  static bool isPiece(Garment garment) {
    final shelf = garment.customShelf?.trim();
    return shelf == goldShelf || shelf == silverShelf;
  }

  static bool isGold(Garment garment) => garment.customShelf?.trim() == goldShelf;

  static const goldKarats = [24, 22, 18];
  static const silverFineness = [999, 925];

  /// Notes stay readable. Weight and purity are stored on the first line.
  static String packNotes({
    required int purity,
    required double grams,
    String note = '',
  }) {
    final body = note.trim();
    final head = '[[jewel $purity ${grams.toStringAsFixed(3)}]]';
    return body.isEmpty ? head : '$head\n$body';
  }

  /// What was paid, and today's metal value, for a set of pieces.
  /// Current stays empty until a rate is available.
  static ({double? purchased, double? current}) worth(
    Iterable<Garment> pieces,
    double? Function(JewelryFacts facts)? ratePerGram,
  ) {
    var paid = 0.0;
    var hasPaid = false;
    var now = 0.0;
    var hasNow = false;
    for (final piece in pieces) {
      final cost = piece.cost;
      if (cost != null) {
        hasPaid = true;
        paid += cost;
      }
      final facts = read(piece);
      final grams = facts.grams;
      final rate = ratePerGram?.call(facts);
      if (grams != null && rate != null) {
        hasNow = true;
        now += grams * rate;
      }
    }
    return (
      purchased: hasPaid ? paid : null,
      current: hasNow ? now : null,
    );
  }

  static JewelryFacts read(Garment garment) {
    final raw = garment.notes;
    final match = RegExp(r'^\[\[jewel (\d+) ([0-9.]+)\]\]\n?').firstMatch(raw);
    if (match == null) {
      return JewelryFacts(
        purity: isGold(garment) ? 22 : 925,
        grams: null,
        note: raw,
      );
    }
    return JewelryFacts(
      purity: int.parse(match.group(1)!),
      grams: double.tryParse(match.group(2)!),
      note: raw.substring(match.end),
    );
  }
}

class JewelryFacts {
  const JewelryFacts({
    required this.purity,
    required this.grams,
    required this.note,
  });

  final int purity;
  final double? grams;
  final String note;

  String get purityLabel {
    if (purity >= 100) return '.$purity';
    return '${purity}K';
  }
}
