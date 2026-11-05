import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/wardrobe_decor.dart';

/// Persists gif-style stickers placed on wardrobe shelves.
class WardrobeDecorController extends ChangeNotifier {
  WardrobeDecorController();

  static const _key = 'mine_wardrobe_decor_v1';
  final _uuid = const Uuid();

  List<WardrobeDecorPlacement> placements = [];
  bool loaded = false;
  bool customizeMode = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        placements = list
            .map(
              (e) => WardrobeDecorPlacement.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .where((p) => decorKindById(p.decorId) != null)
            .toList();
      }
    } catch (e) {
      debugPrint('Decor load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(placements.map((p) => p.toJson()).toList()),
    );
  }

  List<WardrobeDecorPlacement> forShelf(String shelfLabel) {
    return placements.where((p) => p.shelfLabel == shelfLabel).toList();
  }

  void setCustomizeMode(bool on) {
    if (customizeMode == on) return;
    customizeMode = on;
    notifyListeners();
  }

  Future<void> addToShelf(String shelfLabel, String decorId) async {
    if (decorKindById(decorId) == null) return;
    placements = [
      ...placements,
      WardrobeDecorPlacement(
        id: _uuid.v4(),
        decorId: decorId,
        shelfLabel: shelfLabel,
      ),
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> removePlacement(String placementId) async {
    placements = placements.where((p) => p.id != placementId).toList();
    notifyListeners();
    await _persist();
  }

  /// Full snapshot for backup / restore (no live controller needed).
  static Future<List<Map<String, dynamic>>> exportAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list)
          if (e is Map<String, dynamic>) e
          else if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> importAll(List<dynamic>? raw) async {
    if (raw == null) return;
    final incoming = <WardrobeDecorPlacement>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        final place = WardrobeDecorPlacement.fromJson(
          Map<String, dynamic>.from(e),
        );
        if (decorKindById(place.decorId) != null) incoming.add(place);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_key);
    final merged = <String, WardrobeDecorPlacement>{};
    if (existingRaw != null && existingRaw.isNotEmpty) {
      try {
        for (final e in jsonDecode(existingRaw) as List<dynamic>) {
          if (e is! Map) continue;
          final place = WardrobeDecorPlacement.fromJson(
            Map<String, dynamic>.from(e),
          );
          merged[place.id] = place;
        }
      } catch (_) {}
    }
    for (final place in incoming) {
      merged[place.id] = place;
    }
    await prefs.setString(
      _key,
      jsonEncode(merged.values.map((p) => p.toJson()).toList()),
    );
  }
}
