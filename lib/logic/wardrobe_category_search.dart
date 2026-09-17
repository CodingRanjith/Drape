import 'package:flutter/material.dart';

import '../models/wardrobe.dart';

/// Words and typos people type that should map onto a cupboard category.
const Map<WardrobeCategory, List<String>> wardrobeCategoryAliases = {
  WardrobeCategory.topwear: [
    'top',
    'tops',
    'blouse',
    'kurti',
    'crop top',
    'tank',
    'camisole',
    'upper',
  ],
  WardrobeCategory.tshirts: [
    'tshirt',
    't shirt',
    'tee',
    'tees',
    'polo',
  ],
  WardrobeCategory.shirts: [
    'shirt',
    'formal shirt',
    'oxford',
    'button up',
  ],
  WardrobeCategory.bottomwear: [
    'bottom',
    'bottoms',
    'bottom wear',
    'pant',
    'pants',
    'legwear',
  ],
  WardrobeCategory.jeans: [
    'denim',
    'jean',
  ],
  WardrobeCategory.trousers: [
    'trouser',
    'chinos',
    'formal pants',
    'slacks',
  ],
  WardrobeCategory.shorts: [
    'short',
    'bermuda',
    'cargo shorts',
  ],
  WardrobeCategory.skirts: [
    'skirt',
    'midi skirt',
    'mini skirt',
  ],
  WardrobeCategory.dresses: [
    'dress',
    'gown',
    'frock',
    'maxi',
    'midi',
  ],
  WardrobeCategory.ethnicWear: [
    'ethnic',
    'kurta',
    'salwar',
    'anarkali',
    'lehenga',
    'sherwani',
    'traditional',
  ],
  WardrobeCategory.sarees: [
    'saree',
    'sari',
    'sarees',
  ],
  WardrobeCategory.outerwear: [
    'jacket',
    'coat',
    'blazer',
    'hoodie',
    'shawl',
    'shrug',
    'cardigan',
    'cape',
  ],
  WardrobeCategory.sweaters: [
    'sweater',
    'pullover',
    'jumper',
    'knit',
    'woolen',
  ],
  WardrobeCategory.activewear: [
    'gym',
    'sportswear',
    'workout',
    'tracksuit',
    'leggings',
    'yoga',
  ],
  WardrobeCategory.sleepwear: [
    'nightwear',
    'night dress',
    'nightdress',
    'pyjama',
    'pajama',
    'loungewear',
  ],
  WardrobeCategory.footwear: [
    'shoes',
    'shoe',
    'sneakers',
    'boots',
    'heels',
    'flats',
    'loafers',
    'slippers',
    'footware',
    'foot wear',
  ],
  WardrobeCategory.sandals: [
    'sandal',
    'flip flop',
    'chappal',
    'slides',
  ],
  WardrobeCategory.innerwear: [
    'underwear',
    'lingerie',
    'bra',
    'brief',
    'thermals',
  ],
  WardrobeCategory.socks: [
    'sock',
    'stockings',
    'ankle socks',
  ],
  WardrobeCategory.accessories: [
    'accessory',
    'watch',
    'sunglasses',
    'glasses',
    'specs',
    'hairband',
    'scrunchie',
  ],
  WardrobeCategory.jewellery: [
    'jewelry',
    'jewellery',
    'necklace',
    'nekless',
    'neckless',
    'necklase',
    'chain',
    'pendant',
    'earring',
    'earrings',
    'ring',
    'rings',
    'bracelet',
    'bangle',
    'bangles',
    'anklet',
    'maang tikka',
    'nose ring',
    'mangalsutra',
  ],
  WardrobeCategory.bags: [
    'bag',
    'handbag',
    'purse',
    'clutch',
    'backpack',
    'tote',
    'sling',
  ],
  WardrobeCategory.belts: [
    'belt',
    'waist belt',
  ],
  WardrobeCategory.scarves: [
    'scarf',
    'stole',
    'dupatta',
    'muffler',
  ],
  WardrobeCategory.caps: [
    'cap',
    'hat',
    'beanie',
    'helmet',
    'headwear',
  ],
};

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _compact(String value) => _normalize(value).replaceAll(' ', '');

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

class WardrobeCategoryMatch {
  const WardrobeCategoryMatch({
    required this.label,
    required this.score,
    this.category,
    this.isCustom = false,
    this.reason,
  });

  /// Built-in category, or null when [isCustom].
  final WardrobeCategory? category;
  final String label;
  final bool isCustom;
  final int score;
  final String? reason;

  IconData get icon =>
      isCustom ? Icons.category_outlined : category!.icon;
}

/// Ranks gender-only categories (+ user custom shelves). Never mixes men/women lists.
List<WardrobeCategoryMatch> searchWardrobeCategories(
  String query, {
  required Wearer wearer,
  List<String> customShelves = const [],
}) {
  final pool = WardrobeCategoryX.forWearer(wearer);
  final customs = customShelves
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final q = _normalize(query);

  if (q.isEmpty) {
    return [
      for (final category in pool)
        WardrobeCategoryMatch(
          category: category,
          label: category.label,
          score: 0,
        ),
      for (final custom in customs)
        WardrobeCategoryMatch(
          label: custom,
          isCustom: true,
          score: 0,
          reason: 'Your category',
        ),
    ];
  }

  final compactQ = _compact(q);
  final matches = <WardrobeCategoryMatch>[];

  for (final category in pool) {
    final label = _normalize(category.label);
    final compactLabel = _compact(category.label);
    final aliases = wardrobeCategoryAliases[category] ?? const <String>[];
    var best = 0;
    String? reason;

    void consider(int score, String? why) {
      if (score > best) {
        best = score;
        reason = why;
      }
    }

    if (label == q || compactLabel == compactQ) {
      consider(100, null);
    } else if (label.startsWith(q) || compactLabel.startsWith(compactQ)) {
      consider(90, null);
    } else if (label.contains(q) || compactLabel.contains(compactQ)) {
      consider(80, null);
    } else {
      final labelDist = _levenshtein(compactQ, compactLabel);
      if (compactQ.length >= 3 && labelDist <= 2) {
        consider(70 - labelDist, 'Close to ${category.label}');
      }
    }

    for (final alias in aliases) {
      final a = _normalize(alias);
      final ca = _compact(alias);
      if (a == q || ca == compactQ) {
        consider(95, 'Matches “$alias”');
      } else if (a.startsWith(q) || ca.startsWith(compactQ)) {
        consider(88, 'Matches “$alias”');
      } else if (a.contains(q) || ca.contains(compactQ) || q.contains(a)) {
        consider(78, 'Related to “$alias”');
      } else {
        final dist = _levenshtein(compactQ, ca);
        final allowed = ca.length <= 5 ? 1 : 2;
        if (compactQ.length >= 3 && dist <= allowed) {
          consider(72 - dist, 'Did you mean “$alias”?');
        }
      }
    }

    if (best > 0) {
      matches.add(
        WardrobeCategoryMatch(
          category: category,
          label: category.label,
          score: best,
          reason: reason,
        ),
      );
    }
  }

  for (final custom in customs) {
    final label = _normalize(custom);
    final compactLabel = _compact(custom);
    var best = 0;
    if (label == q || compactLabel == compactQ) {
      best = 100;
    } else if (label.startsWith(q) || compactLabel.startsWith(compactQ)) {
      best = 90;
    } else if (label.contains(q) || compactLabel.contains(compactQ)) {
      best = 80;
    } else {
      final dist = _levenshtein(compactQ, compactLabel);
      if (compactQ.length >= 3 && dist <= 2) best = 70 - dist;
    }
    if (best > 0) {
      matches.add(
        WardrobeCategoryMatch(
          label: custom,
          isCustom: true,
          score: best,
          reason: 'Your category',
        ),
      );
    }
  }

  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.label.compareTo(b.label);
  });
  return matches;
}

/// True when typed text is not an exact built-in/custom match (offer create).
bool canCreateCustomShelf(
  String query, {
  required Wearer wearer,
  List<String> customShelves = const [],
}) {
  final q = query.trim();
  if (q.length < 2) return false;
  final n = _normalize(q);
  for (final category in WardrobeCategoryX.forWearer(wearer)) {
    if (_normalize(category.label) == n) return false;
  }
  for (final custom in customShelves) {
    if (_normalize(custom) == n) return false;
  }
  return true;
}
