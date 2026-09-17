import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import 'persist_image.dart';

class AppStore {
  static const _key = 'drape_state_v1';

  Future<String> saveImage(Uint8List bytes, String id) => persistImage(bytes, id);

  Future<String> saveAudio(
    Uint8List bytes,
    String id, {
    String ext = 'mp3',
    String mime = 'audio/mpeg',
  }) => persistAudio(bytes, id, ext: ext, mime: mime);

  Future<
    ({
      UserProfile profile,
      List<Garment> garments,
      WeekPlan? week,
      List<LifeEvent> events,
      List<PartyLook> partyLooks,
      Set<String> completedDays,
      List<ClothSet> clothSets,
    })
  >
  load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return (
        profile: UserProfile(),
        garments: <Garment>[],
        week: null,
        events: <LifeEvent>[],
        partyLooks: <PartyLook>[],
        completedDays: <String>{},
        clothSets: <ClothSet>[],
      );
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      garments: (json['garments'] as List)
          .map((e) => Garment.fromJson(e as Map<String, dynamic>))
          .toList(),
      week: json['week'] == null
          ? null
          : WeekPlan.fromJson(json['week'] as Map<String, dynamic>),
      events: ((json['events'] as List?) ?? const [])
          .map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      partyLooks: ((json['partyLooks'] as List?) ?? const [])
          .map((e) => PartyLook.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedDays: ((json['completedDays'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      clothSets: ((json['clothSets'] as List?) ?? const [])
          .map((e) => ClothSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> save({
    required UserProfile profile,
    required List<Garment> garments,
    WeekPlan? week,
    required List<LifeEvent> events,
    required List<PartyLook> partyLooks,
    required Set<String> completedDays,
    required List<ClothSet> clothSets,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'profile': profile.toJson(),
        'garments': garments.map((g) => g.toJson()).toList(),
        'week': week?.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'partyLooks': partyLooks.map((e) => e.toJson()).toList(),
        'completedDays': completedDays.toList(),
        'clothSets': clothSets.map((s) => s.toJson()).toList(),
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
