import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chennai jeweller gold and silver rates, in rupees.
class MetalQuote {
  const MetalQuote({
    required this.gold24InrPerGram,
    required this.gold22InrPerGram,
    required this.gold18InrPerGram,
    required this.silver999InrPerGram,
    required this.updatedAt,
    required this.chennai,
  });

  final double gold24InrPerGram;
  final double gold22InrPerGram;
  final double gold18InrPerGram;
  final double silver999InrPerGram;
  final DateTime updatedAt;

  /// True when the numbers are the published Chennai rate, not world spot.
  final bool chennai;

  double goldPerGram(int karat) {
    if (karat >= 23) return gold24InrPerGram;
    if (karat >= 20) return gold22InrPerGram;
    return gold18InrPerGram;
  }

  double silverPerGram(int fineness) => silver999InrPerGram * fineness / 999;
}

class MetalPrices {
  MetalPrices._();
  static final MetalPrices instance = MetalPrices._();

  static const _troyGram = 31.1034768;
  static final _chennaiGold = Uri.parse(
    'https://www.goodreturns.in/gold-rates/chennai.html',
  );
  static final _chennaiSilver = Uri.parse(
    'https://www.goodreturns.in/silver-rates/chennai.html',
  );
  static final _spot = Uri.parse(
    'https://xaus.com/api/v1/spot?currency=INR&unit=gram',
  );

  MetalQuote? _cached;
  DateTime? _fetchedAt;

  MetalQuote? get cached => _cached;

  Future<MetalQuote> fetch({bool force = false}) async {
    final cached = _cached;
    final at = _fetchedAt;
    if (!force &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 15)) {
      return cached;
    }
    try {
      final quote = await _chennai();
      _cached = quote;
      _fetchedAt = DateTime.now();
      return quote;
    } catch (_) {
      try {
        final quote = await _worldSpot();
        _cached = quote;
        _fetchedAt = DateTime.now();
        return quote;
      } catch (error) {
        if (cached != null) return cached;
        rethrow;
      }
    }
  }

  Future<MetalQuote> _chennai() async {
    final goldPage = await http
        .get(_chennaiGold)
        .timeout(const Duration(seconds: 12));
    final silverPage = await http
        .get(_chennaiSilver)
        .timeout(const Duration(seconds: 12));
    if (goldPage.statusCode != 200 || silverPage.statusCode != 200) {
      throw Exception('Chennai rate page failed');
    }
    final block = RegExp(
      r'currentMetalPrices\s*=\s*\{([^}]+)\}',
    ).firstMatch(goldPage.body)?.group(1);
    if (block == null) throw Exception('Chennai gold block missing');
    final gold24 = _field(block, '24');
    final gold22 = _field(block, '22');
    final gold18 = _field(block, '18');
    final silver = _silverGram(silverPage.body);
    if (gold24 == null || gold22 == null || gold18 == null || silver == null) {
      throw Exception('Chennai rate page changed');
    }
    if (gold24 < 1000 || silver < 10) {
      throw Exception('Chennai rate looked wrong');
    }
    return MetalQuote(
      gold24InrPerGram: gold24,
      gold22InrPerGram: gold22,
      gold18InrPerGram: gold18,
      silver999InrPerGram: silver,
      updatedAt: DateTime.now(),
      chennai: true,
    );
  }

  double? _field(String html, String karat) {
    final match = RegExp(
      "['\"]$karat['\"]\\s*:\\s*(\\d+(?:\\.\\d+)?)",
    ).firstMatch(html);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  double? _silverGram(String html) {
    final tagged = RegExp(
      r'&#x20b9;(\d[\d,]*)\s*</strong>\s*per gram',
      caseSensitive: false,
    ).firstMatch(html);
    if (tagged != null) {
      return double.tryParse(tagged.group(1)!.replaceAll(',', ''));
    }
    final plain = RegExp(
      r'₹\s*(\d[\d,]*)\s*</strong>\s*per gram',
      caseSensitive: false,
    ).firstMatch(html);
    if (plain == null) return null;
    return double.tryParse(plain.group(1)!.replaceAll(',', ''));
  }

  Future<MetalQuote> _worldSpot() async {
    final response = await http.get(_spot).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Price request failed');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final xau = json['xau'] as Map<String, dynamic>;
    final fx = (json['fx_rate'] as num).toDouble();
    final gold = xau['unit'] == 'gram'
        ? (xau['price'] as num).toDouble()
        : (json['per_gram_usd'] as num).toDouble() * fx;
    final silverOz = (json['silver_usd_oz'] as num).toDouble();
    final silver = silverOz / _troyGram * fx;
    final updated =
        DateTime.tryParse('${json['updated_at']}')?.toLocal() ?? DateTime.now();
    return MetalQuote(
      gold24InrPerGram: gold,
      gold22InrPerGram: gold * 22 / 24,
      gold18InrPerGram: gold * 18 / 24,
      silver999InrPerGram: silver,
      updatedAt: updated,
      chennai: false,
    );
  }
}

/// Rupee text with Indian grouping. No intl locale init required.
String formatInr(double value, {int digits = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = parts[0];
  final grouped = StringBuffer();
  if (whole.length <= 3) {
    grouped.write(whole);
  } else {
    final tail = whole.substring(whole.length - 3);
    var head = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    grouped
      ..write(groups.join(','))
      ..write(',')
      ..write(tail);
  }
  final fraction = digits > 0 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}₹$grouped$fraction';
}
