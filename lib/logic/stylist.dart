import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/wardrobe.dart';

class Stylist {
  Stylist({Random? random}) : _random = random ?? Random();

  final Random _random;
  final _uuid = const Uuid();

  bool canDress(List<Garment> wardrobe) {
    final clean = wardrobe.where((g) => !g.inLaundry).toList();
    final hasDress = clean.any((g) => g.category == GarmentCategory.dress);
    final hasTop = clean.any((g) => g.category == GarmentCategory.top);
    final hasPant = clean.any((g) => g.category == GarmentCategory.bottom);
    return hasDress || hasTop || hasPant;
  }

  List<Outfit> buildChoices({
    required List<Garment> wardrobe,
    required UserProfile profile,
    required DateTime date,
    Set<String> usedIds = const {},
  }) {
    // Never reuse items already planned elsewhere this week.
    final pool = wardrobe
        .where((g) => !g.inLaundry && !usedIds.contains(g.id))
        .toList();
    final tops = pool.where((g) => g.category == GarmentCategory.top).toList();
    final pants = pool.where((g) => g.category == GarmentCategory.bottom).toList();
    final dresses = pool.where((g) => g.category == GarmentCategory.dress).toList();
    final ranked = <({Outfit outfit, double score})>[];

    void addLook(Outfit outfit, double score) {
      ranked.add((outfit: outfit, score: score));
    }

    for (final dress in dresses) {
      addLook(
        Outfit(id: _uuid.v4(), dressId: dress.id),
        _score(dress, profile, date, const [], usedIds),
      );
    }

    for (final top in tops) {
      var matched = pants.where((pant) => _goesTogether(top, pant)).toList();
      if (matched.isEmpty) matched = [...pants];
      matched.sort(
        (a, b) => _score(b, profile, date, [top], usedIds)
            .compareTo(_score(a, profile, date, [top], usedIds)),
      );
      if (matched.isEmpty) {
        addLook(
          Outfit(id: _uuid.v4(), topId: top.id),
          _score(top, profile, date, const [], usedIds),
        );
        continue;
      }
      for (final pant in matched) {
        addLook(
          Outfit(id: _uuid.v4(), topId: top.id, bottomId: pant.id),
          _score(top, profile, date, const [], usedIds) +
              _score(pant, profile, date, [top], usedIds),
        );
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(24).map((e) => e.outfit).toList();
  }

  bool _goesTogether(Garment top, Garment pant) {
    if (top.pairsWithIds.contains(pant.id) || pant.pairsWithIds.contains(top.id)) {
      return true;
    }
    final anyPairs = top.pairsWithIds.isNotEmpty || pant.pairsWithIds.isNotEmpty;
    if (anyPairs) return false;
    return _harmony(top, [pant]) >= 0.35;
  }

  WeekPlan planWeek({
    required List<Garment> wardrobe,
    required UserProfile profile,
    required DateTime weekStart,
    WeekPlan? existing,
  }) {
    final days = <DayPlan>[];

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final previous = existing?.forDate(date);
      days.add(
        DayPlan(
          date: date,
          outfit: previous?.outfit,
          locked: previous?.locked ?? false,
          worn: previous?.worn ?? false,
        ),
      );
    }

    return WeekPlan(weekStart: weekStart, days: days);
  }

  Outfit? buildOutfit({
    required List<Garment> wardrobe,
    required UserProfile profile,
    required DateTime date,
    required Set<String> usedIds,
    Outfit? keep,
    GarmentCategory? replaceCategory,
  }) {
    final pool = wardrobe.where((g) {
      if (g.inLaundry) return false;
      if (g.season != Season.allSeason && g.season != seasonFor(date)) {
        return false;
      }
      return true;
    }).toList();

    if (keep != null && replaceCategory != null) {
      final next = pick(
        pool.where(
          (g) =>
              g.category == replaceCategory &&
              g.id != keep.idFor(replaceCategory),
        ),
        profile: profile,
        date: date,
        usedIds: usedIds,
        partners: _byIds(
          wardrobe,
          keep.pieceIds.where((id) => id != keep.idFor(replaceCategory)),
        ),
      );
      if (next == null) return keep;
      final copy = keep.copy();
      if (replaceCategory == GarmentCategory.dress) {
        copy.dressId = next.id;
        copy.topId = null;
        copy.bottomId = null;
      } else if (replaceCategory == GarmentCategory.top ||
          replaceCategory == GarmentCategory.bottom) {
        copy.setIdFor(replaceCategory, next.id);
        copy.dressId = null;
      } else {
        copy.setIdFor(replaceCategory, next.id);
      }
      return copy;
    }

    final dresses = pool.where((g) => g.category == GarmentCategory.dress);
    final tops = pool.where((g) => g.category == GarmentCategory.top);
    final bottoms = pool.where((g) => g.category == GarmentCategory.bottom);
    // Uploaded dresses come first: one dress per office day.
    final useDress = dresses.isNotEmpty;

    Outfit outfit;
    if (useDress) {
      final dress = pick(dresses, profile: profile, date: date, usedIds: usedIds);
      if (dress == null) return null;
      outfit = Outfit(id: _uuid.v4(), dressId: dress.id);
    } else if (tops.isNotEmpty && bottoms.isNotEmpty) {
      final top = pick(tops, profile: profile, date: date, usedIds: usedIds);
      if (top == null) return null;
      final bottom = pick(
        bottoms,
        profile: profile,
        date: date,
        usedIds: usedIds,
        partners: [top],
      );
      if (bottom == null) return null;
      outfit = Outfit(id: _uuid.v4(), topId: top.id, bottomId: bottom.id);
    } else if (tops.isNotEmpty) {
      final top = pick(tops, profile: profile, date: date, usedIds: usedIds);
      if (top == null) return null;
      outfit = Outfit(id: _uuid.v4(), topId: top.id);
    } else {
      return null;
    }

    return outfit;
  }

  Garment? pick(
    Iterable<Garment> items, {
    required UserProfile profile,
    required DateTime date,
    required Set<String> usedIds,
    List<Garment> partners = const [],
    bool optional = false,
  }) {
    var list = items.where((g) => !usedIds.contains(g.id)).toList();
    if (list.isEmpty) {
      // Hard rule: do not repeat any item already used this week.
      return null;
    }
    list.sort((a, b) {
      final score = _score(b, profile, date, partners, usedIds)
          .compareTo(_score(a, profile, date, partners, usedIds));
      if (score != 0) return score;
      return a.id.compareTo(b.id);
    });
    final topN = list.take(optional ? min(3, list.length) : min(4, list.length)).toList();
    if (topN.isEmpty) return null;
    return topN[_random.nextInt(topN.length)];
  }

  double _score(
    Garment g,
    UserProfile profile,
    DateTime date,
    List<Garment> partners,
    Set<String> usedIds,
  ) {
    var score = 40.0;
    score += g.daysSinceWorn(date).clamp(0, 60) * 1.4;
    score -= g.wearCount * 6;
    if (g.lastWornAt == null) score += 28;
    if (g.favorite) score += 8;
    if (g.daysSinceWorn(date) < profile.minRepeatDays && g.lastWornAt != null) {
      score -= 50;
    }
    // Same-week item repeats are blocked at pick/buildChoices; keep a heavy
    // penalty as a safety net for any leftover scoring paths.
    if (usedIds.contains(g.id)) score -= 120;

    final styleGap = (g.formality.index - profile.workStyle.index).abs();
    score -= styleGap * 12;
    if (g.formality == profile.workStyle) score += 10;

    if (g.season == seasonFor(date)) score += 12;
    if (g.season == Season.allSeason) score += 4;

    if (partners.isNotEmpty) {
      score += _harmony(g, partners) * 18;
    }
    score += _random.nextDouble() * 6;
    return score;
  }

  List<Garment> _byIds(List<Garment> wardrobe, Iterable<String> ids) {
    final map = {for (final g in wardrobe) g.id: g};
    return ids.map((id) => map[id]).whereType<Garment>().toList();
  }

  double _harmony(Garment candidate, List<Garment> partners) {
    if (candidate.colors.isEmpty) return 0;
    var total = 0.0;
    var n = 0;
    for (final partner in partners) {
      for (final a in candidate.colors) {
        for (final b in partner.colors) {
          total += _pairScore(Color(a), Color(b));
          n++;
        }
      }
    }
    return n == 0 ? 0 : total / n;
  }

  double _pairScore(Color a, Color b) {
    if (_isNeutral(a) || _isNeutral(b)) return 0.9;
    final ha = HSVColor.fromColor(a).hue;
    final hb = HSVColor.fromColor(b).hue;
    final hueGap = min((ha - hb).abs(), 360 - (ha - hb).abs());
    if (hueGap < 25) return 0.85;
    if (hueGap > 140 && hueGap < 220) return 0.7;
    if (hueGap > 70 && hueGap < 110) return 0.2;
    return 0.45;
  }

  bool _isNeutral(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.saturation < 0.18 || hsl.lightness > 0.86 || hsl.lightness < 0.14;
  }
}
