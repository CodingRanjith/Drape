import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../data/backup.dart';
import '../data/media_bytes.dart';
import '../logic/stylist.dart';
import '../models/life.dart';
import '../models/wardrobe.dart';
import '../services/alarm_tone.dart';
import '../services/notify.dart';

class DrapeState extends ChangeNotifier {
  DrapeState({AppStore? store, Stylist? stylist})
    : _store = store ?? AppStore(),
      _stylist = stylist ?? Stylist();

  final AppStore _store;
  final Stylist _stylist;
  final _uuid = const Uuid();
  final _player = AudioPlayer();
  Timer? _alarmWatch;

  bool loading = true;
  UserProfile profile = UserProfile();
  List<Garment> garments = [];
  WeekPlan? week;
  List<Outfit> todayChoices = [];
  int todayIndex = 0;
  List<LifeEvent> events = [];
  List<PartyLook> partyLooks = [];
  Set<String> completedDays = {};
  List<ClothSet> clothSets = [];
  LifeEvent? ringingEvent;
  void Function(String eventId)? onShowAlarm;

  Future<void> boot() async {
    try {
      final data = await _store.load();
      profile = data.profile;
      garments = data.garments;
      week = data.week;
      events = data.events;
      partyLooks = data.partyLooks;
      completedDays = {...data.completedDays};
      clothSets = data.clothSets;
      _ensureCurrentWeek();
      _syncCompletedFromWeek();
    } catch (e, st) {
      debugPrint('Drape boot failed: $e\n$st');
      _ensureCurrentWeek();
    } finally {
      _rebuildTodayChoices();
      loading = false;
      notifyListeners();
    }
    try {
      await _persist();
      await _resyncAlarms();
    } catch (e, st) {
      debugPrint('Drape persist failed: $e\n$st');
    }
    _alarmWatch?.cancel();
    _alarmWatch = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_checkDueAlarms());
    });
    unawaited(_checkDueAlarms());
  }

  @override
  void dispose() {
    _alarmWatch?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  void _ensureCurrentWeek() {
    final start = mondayOf(DateTime.now());
    if (week == null || !sameDay(week!.weekStart, start)) {
      if (_stylist.canDress(garments)) {
        week = _stylist.planWeek(
          wardrobe: garments,
          profile: profile,
          weekStart: start,
        );
      } else {
        week = WeekPlan(
          weekStart: start,
          days: List.generate(
            7,
            (i) => DayPlan(date: start.add(Duration(days: i))),
          ),
        );
      }
    }
  }

  void _syncCompletedFromWeek() {
    if (week == null) return;
    for (final day in week!.days) {
      if (day.worn) completedDays.add(dateKey(day.date));
    }
  }

  Future<void> _persist() => _store.save(
    profile: profile,
    garments: garments,
    week: week,
    events: events,
    partyLooks: partyLooks,
    completedDays: completedDays,
    clothSets: clothSets,
  );

  Future<void> completeOnboarding({
    required String name,
    required Set<int> workdays,
    required Formality workStyle,
    required Wearer wearer,
  }) async {
    profile
      ..name = name.trim().isEmpty ? 'there' : name.trim()
      ..workdays = workdays
      ..workStyle = workStyle
      ..wearer = wearer
      ..onboarded = true;
    regenerateWeek();
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
  }

  Future<void> logoutToWearerChoice() async {
    profile.onboarded = false;
    notifyListeners();
    await _persist();
  }

  Future<void> updateProfile(UserProfile next) async {
    profile = next;
    notifyListeners();
    await _persist();
  }

  Garment? garmentById(String? id) {
    if (id == null) return null;
    for (final g in garments) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Garment> piecesOf(Outfit? outfit) {
    if (outfit == null) return [];
    return outfit.pieceIds.map(garmentById).whereType<Garment>().toList();
  }

  DayPlan? get todayPlan => week?.forDate(DateTime.now());

  bool get isWorkToday => profile.workdays.contains(DateTime.now().weekday);

  bool isDayCompleted(DateTime date) => completedDays.contains(dateKey(date));

  List<LifeEvent> eventsOn(DateTime date) {
    final key = dateKey(date);
    return events.where((e) => dateKey(e.at) == key).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  List<LifeEvent> get upcomingEvents {
    final now = DateTime.now().subtract(const Duration(hours: 1));
    final list = events.where((e) => e.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return list.take(12).toList();
  }

  String get greeting {
    final hour = DateTime.now().hour;
    final name = profile.name;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 17) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  Future<void> saveGarment(Garment garment, {Uint8List? imageBytes}) async {
    if (imageBytes != null) {
      garment.imagePath = await _store.saveImage(imageBytes, garment.id);
    }
    final index = garments.indexWhere((g) => g.id == garment.id);
    if (index >= 0) {
      garments[index] = garment;
    } else {
      garments.add(garment);
    }
    final emptyWeek =
        week == null ||
        week!.days
            .where((d) => profile.workdays.contains(d.date.weekday))
            .every((d) => d.outfit == null || d.outfit!.isEmpty);
    if (emptyWeek && _stylist.canDress(garments)) {
      regenerateWeek();
    }
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
  }

  Garment newGarmentDraft() => Garment(
    id: _uuid.v4(),
    name: '',
    category: GarmentCategory.top,
    colors: [colorArgb(fashionPalette.first.value)],
  );

  Future<void> deleteGarment(String id) async {
    garments.removeWhere((g) => g.id == id);
    if (week != null) {
      for (final day in week!.days) {
        final outfit = day.outfit;
        if (outfit == null) continue;
        for (final category in GarmentCategory.values) {
          if (outfit.idFor(category) == id) {
            outfit.setIdFor(category, null);
          }
        }
        if (outfit.tshirtId == id) outfit.tshirtId = null;
      }
    }
    for (final set in clothSets) {
      for (final category in GarmentCategory.values) {
        if (set.outfit.idFor(category) == id) {
          set.outfit.setIdFor(category, null);
        }
      }
      if (set.outfit.tshirtId == id) set.outfit.tshirtId = null;
    }
    for (final event in events) {
      event.garmentIds.remove(id);
    }
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
  }

  Future<void> toggleLaundry(Garment garment) async {
    garment.inLaundry = !garment.inLaundry;
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
  }

  Future<void> toggleFavorite(Garment garment) async {
    garment.favorite = !garment.favorite;
    notifyListeners();
    await _persist();
  }

  void regenerateWeek({bool keepLocks = true}) {
    final start = mondayOf(DateTime.now());
    week = _stylist.planWeek(
      wardrobe: garments,
      profile: profile,
      weekStart: start,
      existing: keepLocks ? week : null,
    );
    todayIndex = 0;
    _rebuildTodayChoices();
  }

  Future<void> refreshWeek({bool keepLocks = true}) async {
    regenerateWeek(keepLocks: keepLocks);
    notifyListeners();
    await _persist();
  }

  List<Garment> optionsFor(ClothesType type) {
    return garments.where((g) => !g.inLaundry && type.matches(g)).toList();
  }

  Garment? todaySlotGarment(ClothesType type) {
    return garmentById(todayPlan?.outfit?.idForType(type));
  }

  void _fillTodaySlots() {
    final day = todayPlan;
    if (day == null || day.locked || day.worn) return;
    day.outfit ??= Outfit(id: _uuid.v4());
    for (final type in ClothesType.todaySlots(profile.wearer)) {
      final current = garmentById(day.outfit!.idForType(type));
      if (current != null && type.matches(current) && !current.inLaundry) {
        continue;
      }
      final options = optionsFor(type);
      day.outfit!.setIdForType(type, options.isEmpty ? null : options.first.id);
    }
  }

  Future<void> selectTodaySlot(ClothesType type, String garmentId) async {
    final day = todayPlan;
    if (day == null || day.locked || day.worn) return;
    day.outfit ??= Outfit(id: _uuid.v4());
    day.outfit!.setIdForType(type, garmentId);
    notifyListeners();
    await _persist();
  }

  void _rebuildTodayChoices() {
    final day = todayPlan;
    todayChoices = _stylist.buildChoices(
      wardrobe: garments,
      profile: profile,
      date: day?.date ?? DateTime.now(),
      usedIds: _usedIds(except: day),
    );
    if (todayIndex >= todayChoices.length) todayIndex = 0;
    _fillTodaySlots();
  }

  Future<void> showNextLook() async {
    final day = todayPlan;
    if (day == null || day.locked || todayChoices.isEmpty) return;
    todayIndex = (todayIndex + 1) % todayChoices.length;
    day.outfit = todayChoices[todayIndex];
    notifyListeners();
    await _persist();
  }

  Future<void> showPreviousLook() async {
    final day = todayPlan;
    if (day == null || day.locked || todayChoices.isEmpty) return;
    todayIndex = (todayIndex - 1 + todayChoices.length) % todayChoices.length;
    day.outfit = todayChoices[todayIndex];
    notifyListeners();
    await _persist();
  }

  Future<void> acceptToday() async {
    final day = todayPlan;
    if (day == null || day.outfit == null) return;
    day.locked = true;
    await markWorn(day);
  }

  Future<void> shuffleDay(DayPlan day) async {
    if (day.locked) return;
    final used = _usedIds(except: day);
    day.outfit = _stylist.buildOutfit(
      wardrobe: garments,
      profile: profile,
      date: day.date,
      usedIds: used,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> shuffleToday() => showNextLook();

  Future<void> swapPiece(DayPlan day, GarmentCategory category) async {
    if (day.locked || day.outfit == null) return;
    final used = _usedIds(except: day);
    used.addAll(day.outfit!.pieceIds);
    day.outfit = _stylist.buildOutfit(
      wardrobe: garments,
      profile: profile,
      date: day.date,
      usedIds: used,
      keep: day.outfit,
      replaceCategory: category,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> assignPiece(
    DayPlan day,
    GarmentCategory category,
    String? garmentId,
  ) async {
    day.outfit ??= Outfit(id: _uuid.v4());
    _putOnOutfit(day.outfit!, category, garmentId);
    notifyListeners();
    await _persist();
  }

  void _putOnOutfit(Outfit outfit, GarmentCategory category, String? garmentId) {
    if (category == GarmentCategory.dress && garmentId != null) {
      outfit
        ..dressId = garmentId
        ..topId = null
        ..bottomId = null;
    } else if (category == GarmentCategory.top ||
        category == GarmentCategory.bottom) {
      outfit.setIdFor(category, garmentId);
      if (garmentId != null) outfit.dressId = null;
    } else {
      outfit.setIdFor(category, garmentId);
    }
  }

  ClothSet? clothSetById(String? id) {
    if (id == null) return null;
    for (final set in clothSets) {
      if (set.id == id) return set;
    }
    return null;
  }

  List<ClothSet> setsFor(StyleCollection collection) {
    return clothSets.where((s) => s.collection == collection).toList();
  }

  Future<ClothSet> addClothSet(StyleCollection collection) async {
    final set = ClothSet(
      id: _uuid.v4(),
      name: 'Set ${setsFor(collection).length + 1}',
      collection: collection,
    );
    clothSets.add(set);
    notifyListeners();
    await _persist();
    return set;
  }

  Future<void> renameClothSet(String id, String name) async {
    final set = clothSetById(id);
    if (set == null) return;
    set.name = name.trim().isEmpty ? set.name : name.trim();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteClothSet(String id) async {
    clothSets.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> assignToClothSet(
    String setId,
    GarmentCategory category,
    String? garmentId,
  ) async {
    final set = clothSetById(setId);
    if (set == null) return;
    _putOnOutfit(set.outfit, category, garmentId);
    notifyListeners();
    await _persist();
  }

  Future<void> toggleLock(DayPlan day) async {
    day.locked = !day.locked;
    notifyListeners();
    await _persist();
  }

  Future<void> markWorn(DayPlan day) async {
    if (day.outfit == null) return;
    day.worn = true;
    completedDays.add(dateKey(day.date));
    final now = DateTime.now();
    for (final piece in piecesOf(day.outfit)) {
      piece.lastWornAt = now;
      piece.wearCount += 1;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> undoWorn(DayPlan day) async {
    if (!day.worn || day.outfit == null) return;
    day.worn = false;
    completedDays.remove(dateKey(day.date));
    for (final piece in piecesOf(day.outfit)) {
      if (piece.wearCount > 0) piece.wearCount -= 1;
    }
    notifyListeners();
    await _persist();
  }

  Set<String> _usedIds({DayPlan? except}) {
    final ids = <String>{};
    if (week == null) return ids;
    for (final day in week!.days) {
      if (except != null && sameDay(day.date, except.date)) continue;
      ids.addAll(day.outfit?.pieceIds ?? const []);
    }
    return ids;
  }

  List<Garment> neglected({int days = 14}) {
    final now = DateTime.now();
    final list = garments
        .where((g) => !g.inLaundry && g.daysSinceWorn(now) >= days)
        .toList()
      ..sort((a, b) => b.daysSinceWorn(now).compareTo(a.daysSinceWorn(now)));
    return list;
  }

  List<Garment> mostWorn() {
    final list = [...garments]..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    return list.take(5).where((g) => g.wearCount > 0).toList();
  }

  int get plannedWorkdays {
    if (week == null) return 0;
    return week!.days
        .where(
          (d) =>
              profile.workdays.contains(d.date.weekday) &&
              d.outfit != null &&
              !d.outfit!.isEmpty,
        )
        .length;
  }

  int get workdayCount => week == null
      ? 0
      : week!.days.where((d) => profile.workdays.contains(d.date.weekday)).length;

  PartyLook? partyLookById(String? id) {
    if (id == null) return null;
    for (final look in partyLooks) {
      if (look.id == id) return look;
    }
    return null;
  }

  LifeEvent? eventById(String? id) {
    if (id == null) return null;
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  Future<void> savePartyLook(PartyLook look, {Uint8List? imageBytes}) async {
    if (imageBytes != null) {
      look.imagePath = await _store.saveImage(imageBytes, look.id);
    }
    final index = partyLooks.indexWhere((e) => e.id == look.id);
    if (index >= 0) {
      partyLooks[index] = look;
    } else {
      partyLooks.add(look);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> deletePartyLook(String id) async {
    partyLooks.removeWhere((e) => e.id == id);
    for (final event in events) {
      if (event.partyLookId == id) event.partyLookId = null;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> saveEvent(
    LifeEvent event, {
    Uint8List? musicBytes,
    String? musicExt,
    String? musicMime,
  }) async {
    if (musicBytes != null) {
      event.musicPath = await _store.saveAudio(
        musicBytes,
        event.id,
        ext: musicExt ?? 'mp3',
        mime: musicMime ?? 'audio/mpeg',
      );
    }
    event.alarmFired = false;
    final index = events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
    await _scheduleOne(event);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteEvent(String id) async {
    final existing = eventById(id);
    if (existing != null) await cancelEventAlarm(existing.alarmId);
    events.removeWhere((e) => e.id == id);
    if (ringingEvent?.id == id) await stopRinging();
    notifyListeners();
    await _persist();
  }

  Future<void> checkDueAlarms() => _checkDueAlarms();

  Future<void> handleAlarm(String eventId) async {
    final event = eventById(eventId);
    if (event == null) return;
    await startRinging(event);
  }

  Future<void> startRinging(LifeEvent event) async {
    if (ringingEvent?.id == event.id) {
      onShowAlarm?.call(event.id);
      return;
    }
    ringingEvent = event;
    event.alarmFired = true;
    notifyListeners();
    await _persist();
    await _playAlarmMusic(event);
    onShowAlarm?.call(event.id);
  }

  Future<void> stopRinging() async {
    ringingEvent = null;
    try {
      await _player.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> snoozeRinging({int minutes = 5}) async {
    final event = ringingEvent;
    await stopRinging();
    if (event == null) return;
    event
      ..at = DateTime.now().add(Duration(minutes: minutes))
      ..alarmOn = true
      ..alarmFired = false;
    await _scheduleOne(event);
    notifyListeners();
    await _persist();
  }

  Future<void> _playAlarmMusic(LifeEvent event) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1);
      final stored = audioBytesFromStored(event.musicPath);
      if (stored != null) {
        await _player.play(BytesSource(stored));
        return;
      }
      final path = event.musicPath;
      if (path != null &&
          path.isNotEmpty &&
          !path.startsWith('data:') &&
          !kIsWeb) {
        await _player.play(DeviceFileSource(path));
        return;
      }
      await _player.play(BytesSource(buildAlarmWav(seconds: 2)));
    } catch (e) {
      debugPrint('Alarm music failed: $e');
      try {
        await _player.play(BytesSource(buildAlarmWav(seconds: 2)));
      } catch (_) {}
    }
  }

  Future<void> _checkDueAlarms() async {
    if (ringingEvent != null) return;
    final now = DateTime.now();
    final due = events.where((e) {
      if (!e.alarmOn || e.alarmFired) return false;
      return !e.at.isAfter(now);
    }).toList()..sort((a, b) => a.at.compareTo(b.at));
    if (due.isEmpty) return;
    await startRinging(due.first);
  }

  Future<void> _scheduleOne(LifeEvent event) async {
    await cancelEventAlarm(event.alarmId);
    if (!event.alarmOn) return;
    await scheduleEventAlarm(
      id: event.alarmId,
      at: event.at,
      title: event.title,
      body: '${event.kind.label} · time to get ready',
      eventId: event.id,
    );
  }

  Future<void> _resyncAlarms() async {
    for (final event in events) {
      if (event.alarmOn && !event.alarmFired && event.at.isAfter(DateTime.now())) {
        await _scheduleOne(event);
      }
    }
  }

  int get completedThisWeek {
    if (week == null) return 0;
    return week!.days
        .where(
          (d) =>
              profile.workdays.contains(d.date.weekday) &&
              completedDays.contains(dateKey(d.date)),
        )
        .length;
  }

  List<DateTime> get completedDateList {
    final dates = <DateTime>[];
    for (final key in completedDays) {
      final parts = key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;
      dates.add(DateTime(year, month, day));
    }
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  Future<Uint8List> buildBackup() {
    return DrapeBackup.encode(
      profile: profile,
      garments: garments,
      week: week,
      events: events,
      partyLooks: partyLooks,
      completedDays: completedDays,
      clothSets: clothSets,
    );
  }

  Future<({int clothes, int looks, int events})> restoreBackup(
    Uint8List bytes,
  ) async {
    final packed = DrapeBackup.decode(bytes);
    final json = packed.json;
    final filesOnly = json['filesOnly'] == true || !packed.hasProfile;
    if (!packed.hasProfile && packed.imageFiles().isEmpty) {
      throw const FormatException('This is not a Drape backup zip.');
    }

    if (!filesOnly) {
      for (final event in events) {
        await cancelEventAlarm(event.alarmId);
      }
      await stopRinging();

      profile = UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
      week = json['week'] == null
          ? null
          : WeekPlan.fromJson(json['week'] as Map<String, dynamic>);
      completedDays = ((json['completedDays'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet();
      clothSets = ((json['clothSets'] as List?) ?? const [])
          .map((e) => ClothSet.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final usedKeys = <String>{};
    Future<String?> storePhoto(String? path, String id) async {
      final match = packed.matchFile(path, id: id);
      if (match == null || match.value.isEmpty) return null;
      usedKeys.add(match.key);
      return _store.saveImage(match.value, id);
    }

    final nextGarments = filesOnly ? [...garments] : <Garment>[];
    for (final raw in (json['garments'] as List? ?? const [])) {
      final garment = Garment.fromJson(raw as Map<String, dynamic>);
      garment.imagePath = await storePhoto(garment.imagePath, garment.id);
      nextGarments.add(garment);
    }

    for (final entry in packed.imageFiles()) {
      final key = normalizeZipPath(entry.key);
      if (usedKeys.contains(key)) continue;
      final lower = key.toLowerCase();
      if (lower.contains('/party/') || lower.contains('/music/')) continue;
      final id = _uuid.v4();
      final name = zipBaseName(entry.key).replaceFirst(RegExp(r'\.[^.]+$'), '');
      usedKeys.add(key);
      nextGarments.add(
        Garment(
          id: id,
          name: name.isEmpty ? 'Imported photo' : name,
          category: GarmentCategory.top,
          colors: const [0xFFD9C7B8],
          imagePath: await _store.saveImage(entry.value, id),
        ),
      );
    }
    garments = nextGarments;

    if (!filesOnly) {
      final nextLooks = <PartyLook>[];
      for (final raw in (json['partyLooks'] as List? ?? const [])) {
        final look = PartyLook.fromJson(raw as Map<String, dynamic>);
        look.imagePath = await storePhoto(look.imagePath, look.id);
        nextLooks.add(look);
      }
      partyLooks = nextLooks;

      final nextEvents = <LifeEvent>[];
      for (final raw in (json['events'] as List? ?? const [])) {
        final event = LifeEvent.fromJson(raw as Map<String, dynamic>);
        final music = packed.fileFor(event.musicPath, id: event.id);
        if (music != null && music.isNotEmpty) {
          final ext = fileExt(event.musicPath, fallback: 'mp3');
          event.musicPath = await _store.saveAudio(
            music,
            event.id,
            ext: ext,
            mime: audioMime(ext),
          );
        } else {
          event.musicPath = null;
        }
        nextEvents.add(event);
      }
      events = nextEvents;
    }

    todayIndex = 0;
    _ensureCurrentWeek();
    _syncCompletedFromWeek();
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
    await _resyncAlarms();
    return (
      clothes: garments.length,
      looks: partyLooks.length,
      events: events.length,
    );
  }
}
