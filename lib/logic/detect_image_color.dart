import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/wardrobe.dart';

/// Detects the main clothing color(s) from a photo.
/// Prefers opaque pixels (works well after background removal).
/// Maps to the nearest [fashionPalette] swatch — no manual typing.
List<int> detectClothesColors(
  Uint8List bytes, {
  int maxColors = 2,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];

    // Downscale for speed.
    final sample = decoded.width > 160
        ? img.copyResize(decoded, width: 160)
        : decoded;

    final buckets = <int, _Bucket>{};
    var opaqueCount = 0;

    for (final pixel in sample) {
      final a = pixel.a.toInt();
      if (a < 40) continue; // skip transparent / cutout BG
      opaqueCount++;

      // Skip near-white paper / near-black noise edges a bit less aggressively
      // after we already require alpha — still ignore pure extremes lightly.
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Quantize to reduce noise (16 levels per channel).
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      final bucket = buckets.putIfAbsent(key, _Bucket.new);
      bucket.count++;
      bucket.r += r;
      bucket.g += g;
      bucket.b += b;
    }

    if (opaqueCount == 0 || buckets.isEmpty) return const [];

    final ranked = buckets.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final picked = <Color>[];
    for (final bucket in ranked) {
      if (picked.length >= maxColors) break;
      final avg = Color.fromARGB(
        255,
        (bucket.r / bucket.count).round().clamp(0, 255),
        (bucket.g / bucket.count).round().clamp(0, 255),
        (bucket.b / bucket.count).round().clamp(0, 255),
      );
      final mapped = _nearestPalette(avg);
      if (picked.any((c) => _colorDistance(c, mapped) < 28)) continue;
      picked.add(mapped);
    }

    if (picked.isEmpty) {
      return [colorArgb(_nearestPalette(ranked.first.asColor))];
    }
    return picked.map(colorArgb).toList(growable: false);
  } catch (_) {
    return const [];
  }
}

Color _nearestPalette(Color color) {
  var best = fashionPalette.first.value;
  var bestDist = double.infinity;
  for (final swatch in fashionPalette) {
    final d = _colorDistance(color, swatch.value);
    if (d < bestDist) {
      bestDist = d;
      best = swatch.value;
    }
  }
  return best;
}

double _colorDistance(Color a, Color b) {
  final ar = (a.toARGB32() >> 16) & 0xFF;
  final ag = (a.toARGB32() >> 8) & 0xFF;
  final ab = a.toARGB32() & 0xFF;
  final br = (b.toARGB32() >> 16) & 0xFF;
  final bg = (b.toARGB32() >> 8) & 0xFF;
  final bb = b.toARGB32() & 0xFF;
  final dr = (ar - br).toDouble();
  final dg = (ag - bg).toDouble();
  final db = (ab - bb).toDouble();
  final al = 0.299 * ar + 0.587 * ag + 0.114 * ab;
  final bl = 0.299 * br + 0.587 * bg + 0.114 * bb;
  final dl = al - bl;
  return math.sqrt(dr * dr + dg * dg + db * db + dl * dl * 0.5);
}

class _Bucket {
  int count = 0;
  int r = 0;
  int g = 0;
  int b = 0;

  Color get asColor => Color.fromARGB(
        255,
        (r / count).round().clamp(0, 255),
        (g / count).round().clamp(0, 255),
        (b / count).round().clamp(0, 255),
      );
}
