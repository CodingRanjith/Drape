import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../data/backup.dart';
import '../data/excel_backup.dart';
import '../data/media_bytes.dart';
import '../data/persist_image.dart';
import '../logic/stylist.dart';
import '../models/bucket_list.dart';
import '../models/life.dart';
import '../models/notice.dart';
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
  List<StyleBucketItem> bucketList = [];
  List<AppNotice> notices = [];
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
      bucketList = data.bucketList;
      notices = data.notices;
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
    _suggestWeekFromSets(reshuffle: false);
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
    bucketList: bucketList,
    notices: notices,
  );

  Future<void> completeWalkthrough() async {
    profile.walkthroughSeen = true;
    notifyListeners();
    await _persist();
  }

  Future<void> completeOnboarding({
    required String name,
    required Set<int> workdays,
    required Formality workStyle,
    required Wearer wearer,
    DateTime? dateOfBirth,
    Uint8List? photoBytes,
  }) async {
    profile
      ..name = name.trim().isEmpty ? 'there' : name.trim()
      ..workdays = workdays
      ..workStyle = workStyle
      ..wearer = wearer
      ..dateOfBirth = dateOfBirth
      ..onboarded = true;
    if (photoBytes != null) {
      profile.photoPath = await _store.saveImage(
        photoBytes,
        'profile_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    regenerateWeek();
    _rebuildTodayChoices();
    notifyListeners();
    await _persist();
  }

  Future<void> saveProfilePhoto(Uint8List bytes) async {
    profile.photoPath = await _store.saveImage(
      bytes,
      'profile_${DateTime.now().millisecondsSinceEpoch}',
    );
    notifyListeners();
    await _persist();
  }

  Future<void> logoutToWearerChoice() async {
    profile.onboarded = false;
    notifyListeners();
    await _persist();
  }

  Future<void> clearAllData() async {
    for (final event in events) {
      await cancelEventAlarm(event.alarmId);
    }
    await stopRinging();
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      await cancelEventAlarm(officeNotifId(day));
    }
    await cancelEventAlarm(_officeSnoozeNotifId);

    final seenWalkthrough = profile.walkthroughSeen;
    profile = UserProfile(
      walkthroughSeen: seenWalkthrough,
      onboarded: true,
    );
    garments = [];
    week = null;
    events = [];
    partyLooks = [];
    completedDays = {};
    clothSets = [];
    bucketList = [];
    notices = [];
    todayChoices = [];
    todayIndex = 0;
    ringingEvent = null;
    _ensureCurrentWeek();
    _rebuildTodayChoices();
    notifyListeners();
    await _store.clear();
    await clearPersistedMedia();
    await _persist();
  }

  Future<void> updateProfile(UserProfile next) async {
    profile = next;
    notifyListeners();
    await _persist();
  }

  Future<void> addCustomShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    final exists = profile.customShelves.any(
      (e) => e.toLowerCase() == label.toLowerCase(),
    );
    if (exists) return;
    profile.customShelves = [...profile.customShelves, label];
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

  /// Outfit pieces for a calendar day: event clothes first, then week plan.
  List<Garment> outfitPiecesFor(DateTime date) {
    for (final event in eventsOn(date)) {
      final clothes = event.garmentIds
          .map(garmentById)
          .whereType<Garment>()
          .toList();
      if (clothes.isNotEmpty) return clothes;
    }
    return piecesOf(week?.forDate(date)?.outfit);
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

  static const officeAlarmId = 'office-alarm';
  static const _officeSnoozeNotifId = 9199;

  static int officeNotifId(int weekday) => 9100 + weekday;

  LifeEvent get officeAlarmEvent {
    final now = DateTime.now();
    return LifeEvent(
      id: officeAlarmId,
      title: 'Office day',
      kind: EventKind.other,
      at: DateTime(
        now.year,
        now.month,
        now.day,
        profile.officeAlarmHour,
        profile.officeAlarmMinute,
      ),
      alarmOn: profile.officeAlarmOn,
      musicPath: profile.officeAlarmMusicPath,
      musicName: profile.officeAlarmMusicName,
    );
  }

  int get homeNoticeCount {
    final unread = notices.where((n) => !n.read).length;
    final live = notificationFeed.where((n) => n.id.startsWith('live-')).length;
    return unread + live;
  }

  List<AppNotice> get notificationFeed {
    final live = <AppNotice>[];
    for (final event in upcomingEvents) {
      live.add(
        AppNotice(
          id: 'live-event-${event.id}',
          title: event.title,
          body: event.kind.label,
          kind: 'event',
          at: event.at,
        ),
      );
    }
    final today = todayPlan;
    if (today?.outfit != null &&
        !today!.outfit!.isEmpty &&
        today.worn != true) {
      live.add(
        AppNotice(
          id: 'live-today',
          title: "Today's outfit is ready",
          body: 'Open Home to confirm what you will wear.',
          kind: 'outfit',
        ),
      );
    }
    final seen = <String>{};
    return [
      for (final notice in [...live, ...notices])
        if (notice.kind != 'alarm' && seen.add(notice.id)) notice,
    ];
  }

  void _note(String title, {String body = '', String kind = 'update'}) {
    notices.insert(
      0,
      AppNotice(
        id: _uuid.v4(),
        title: title,
        body: body,
        kind: kind,
      ),
    );
    if (notices.length > 80) {
      notices = notices.take(80).toList();
    }
  }

  Future<void> markNoticesRead() async {
    var changed = false;
    for (final notice in notices) {
      if (!notice.read) {
        notice.read = true;
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> saveGarment(Garment garment, {Uint8List? imageBytes}) async {
    if (imageBytes != null) {
      garment.imagePath = await _store.saveImage(imageBytes, garment.id);
    }
    final index = garments.indexWhere((g) => g.id == garment.id);
    final isNew = index < 0;
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
    if (isNew) {
      _note(
        'Added ${garment.name.trim().isEmpty ? garment.typeLabel : garment.name}',
        body: garment.wardrobeCategory.label,
        kind: 'clothes',
      );
    }
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
    _suggestWeekFromSets(reshuffle: false);
    _rebuildTodayChoices();
  }

  Future<void> refreshWeek({bool keepLocks = true}) async {
    regenerateWeek(keepLocks: keepLocks);
    notifyListeners();
    await _persist();
  }

  /// Cloth sets that have at least one uploaded photo piece.
  List<ClothSet> get readyClothSets {
    return clothSets.where((set) {
      for (final id in set.outfit.pieceIds) {
        final g = garmentById(id);
        if (g != null &&
            g.imagePath != null &&
            g.imagePath!.trim().isNotEmpty &&
            !g.inLaundry) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// Uploaded dress looks usable as a one-piece set.
  List<Outfit> get readyDressLooks {
    return garments
        .where(
          (g) =>
              g.category == GarmentCategory.dress &&
              !g.inLaundry &&
              g.imagePath != null &&
              g.imagePath!.trim().isNotEmpty,
        )
        .map((g) => Outfit(id: _uuid.v4(), dressId: g.id))
        .toList();
  }

  List<Outfit> get _suggestableLooks {
    final looks = <Outfit>[
      for (final set in readyClothSets) set.outfit.copy(id: _uuid.v4()),
    ];
    if (looks.length >= 7) return looks;
    // Fall back to uploaded dresses so week can still auto-fill.
    looks.addAll(readyDressLooks);
    return looks;
  }

  int get suggestableLookCount => _suggestableLooks.length;

  /// Randomly fills Mon–Sun from uploaded sets.
  /// - Need **7+** looks to auto-suggest.
  /// - With **14+** looks, [reshuffle] assigns a fresh different set each day.
  void _suggestWeekFromSets({required bool reshuffle}) {
    if (week == null) return;
    final looks = [..._suggestableLooks];
    if (looks.length < 7) return;

    looks.shuffle();
    final picks = looks.take(7).toList();

    for (var i = 0; i < week!.days.length; i++) {
      final day = week!.days[i];
      if (day.locked || day.worn) continue;
      final hasLook = day.outfit != null && !day.outfit!.isEmpty;

      // 7–13 sets: only fill empty days (unless forced reshuffle from UI).
      // 14+ sets: reshuffle replaces unlocked days with new random picks.
      if (hasLook) {
        if (!reshuffle) continue;
        if (looks.length < 14) continue;
      }

      day.outfit = picks[i].copy(id: _uuid.v4());
    }
  }

  Future<void> suggestWeekSets({bool reshuffle = false}) async {
    _ensureCurrentWeek();
    final force = reshuffle || suggestableLookCount >= 14;
    _suggestWeekFromSets(reshuffle: force);
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
    final used = _usedIds(except: day);
    for (final type in ClothesType.todaySlots(profile.wearer)) {
      final current = garmentById(day.outfit!.idForType(type));
      if (current != null &&
          type.matches(current) &&
          !current.inLaundry &&
          !used.contains(current.id)) {
        continue;
      }
      final options = optionsFor(type)
          .where((g) => !used.contains(g.id))
          .toList();
      day.outfit!.setIdForType(type, options.isEmpty ? null : options.first.id);
    }
  }

  Future<void> selectTodaySlot(ClothesType type, String garmentId) async {
    final day = todayPlan;
    if (day == null || day.locked || day.worn) return;
    if (isUsedElsewhereThisWeek(garmentId, except: day)) return;
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
    _note(
      "Today's look saved",
      body: 'This outfit is locked for today.',
      kind: 'outfit',
    );
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

  Future<void> clearDayOutfit(DayPlan day) async {
    if (day.locked) return;
    day.outfit = null;
    if (day.worn) {
      day.worn = false;
      completedDays.remove(dateKey(day.date));
    }
    notifyListeners();
    await _persist();
  }

  /// Cycles to the next/previous alternate look for [day] (`direction` ±1).
  /// Skips any look that reuses items already planned on another day this week.
  Future<void> cycleDayLook(DayPlan day, int direction) async {
    if (day.locked) return;
    final used = _usedIds(except: day);
    final choices = _stylist
        .buildChoices(
          wardrobe: garments,
          profile: profile,
          date: day.date,
          usedIds: used,
        )
        .where((o) => o.pieceIds.every((id) => !used.contains(id)))
        .toList();
    if (choices.isEmpty) {
      await shuffleDay(day);
      return;
    }

    var index = 0;
    final currentIds = {...?day.outfit?.pieceIds};
    if (currentIds.isNotEmpty) {
      final found = choices.indexWhere(
        (o) =>
            o.pieceIds.length == currentIds.length &&
            o.pieceIds.every(currentIds.contains),
      );
      if (found >= 0) index = found;
    }

    final next = (index + direction) % choices.length;
    day.outfit = choices[next < 0 ? next + choices.length : next];
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

  /// Returns `false` if [garmentId] is already used on another day this week.
  Future<bool> assignPiece(
    DayPlan day,
    GarmentCategory category,
    String? garmentId, {
    TopKind topKind = TopKind.top,
  }) async {
    if (garmentId != null &&
        isUsedElsewhereThisWeek(garmentId, except: day)) {
      return false;
    }
    day.outfit ??= Outfit(id: _uuid.v4());
    final garment = garmentId == null ? null : garmentById(garmentId);
    final kind = garment?.topKind ?? topKind;
    if (kind == TopKind.tshirt) {
      day.outfit!.tshirtId = garmentId;
      if (garmentId != null) day.outfit!.dressId = null;
    } else {
      _putOnOutfit(day.outfit!, category, garmentId);
    }
    notifyListeners();
    await _persist();
    return true;
  }

  /// Removes a specific wardrobe piece from [day]'s outfit.
  Future<void> clearGarmentFromDay(DayPlan day, Garment garment) async {
    final outfit = day.outfit;
    if (outfit == null) return;
    if (outfit.tshirtId == garment.id) {
      outfit.tshirtId = null;
    } else if (outfit.idFor(garment.category) == garment.id) {
      _putOnOutfit(outfit, garment.category, null);
    } else {
      return;
    }
    notifyListeners();
    await _persist();
  }

  void _putOnOutfit(Outfit outfit, GarmentCategory category, String? garmentId) {
    if (category == GarmentCategory.dress && garmentId != null) {
      outfit
        ..dressId = garmentId
        ..topId = null
        ..bottomId = null
        ..tshirtId = null;
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

  /// Singles tagged to this collection (not set-only pieces).
  List<Garment> singlesFor(StyleCollection collection) {
    return garments.where((g) => g.styleCollection == collection).toList();
  }

  bool collectionHasContent(StyleCollection collection) {
    return singlesFor(collection).isNotEmpty || setsFor(collection).isNotEmpty;
  }

  int collectionItemCount(StyleCollection collection) {
    final setPieceIds = <String>{};
    for (final set in setsFor(collection)) {
      setPieceIds.addAll(set.outfit.pieceIds);
    }
    return singlesFor(collection).length + setPieceIds.length;
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

  List<StyleBucketItem> get openBucketItems {
    final items = bucketList.where((b) => !b.isCompleted).toList();
    items.sort((a, b) {
      if (a.starred != b.starred) return a.starred ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  List<StyleBucketItem> get completedBucketItems {
    final items = bucketList.where((b) => b.isCompleted).toList();
    items.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return items;
  }

  double get bucketProgress {
    if (bucketList.isEmpty) return 0;
    return completedBucketItems.length / bucketList.length;
  }

  StyleBucketItem? bucketById(String id) {
    for (final item in bucketList) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<StyleBucketItem> addBucketItem({
    required String title,
    String note = '',
    BucketVibe vibe = BucketVibe.styleChallenge,
  }) async {
    final item = StyleBucketItem(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'New style dream' : title.trim(),
      note: note.trim(),
      vibe: vibe,
    );
    bucketList = [item, ...bucketList];
    _note(
      'Added to bucket list',
      body: item.title,
      kind: 'bucket',
    );
    notifyListeners();
    await _persist();
    return item;
  }

  Future<void> updateBucketItem(
    String id, {
    String? title,
    String? note,
    BucketVibe? vibe,
  }) async {
    final item = bucketById(id);
    if (item == null) return;
    if (title != null) {
      final next = title.trim();
      if (next.isNotEmpty) item.title = next;
    }
    if (note != null) item.note = note.trim();
    if (vibe != null) item.vibe = vibe;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleBucketStar(String id) async {
    final item = bucketById(id);
    if (item == null) return;
    item.starred = !item.starred;
    notifyListeners();
    await _persist();
  }

  Future<void> completeBucketItem(String id) async {
    final item = bucketById(id);
    if (item == null || item.isCompleted) return;
    item.completedAt = DateTime.now();
    _note('Bucket item done', body: item.title, kind: 'bucket');
    notifyListeners();
    await _persist();
  }

  Future<void> reopenBucketItem(String id) async {
    final item = bucketById(id);
    if (item == null || !item.isCompleted) return;
    item.completedAt = null;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteBucketItem(String id) async {
    bucketList = bucketList.where((b) => b.id != id).toList();
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
    _suggestWeekFromSets(reshuffle: false);
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

  /// True if this garment is already on another day's look this week.
  bool isUsedElsewhereThisWeek(String garmentId, {DayPlan? except}) {
    return _usedIds(except: except).contains(garmentId);
  }

  /// Closet options for [category] that are still free this week for [day].
  List<Garment> availableForDay(DayPlan day, GarmentCategory category) {
    final used = _usedIds(except: day);
    return garments
        .where(
          (g) =>
              g.category == category &&
              !g.inLaundry &&
              !used.contains(g.id),
        )
        .toList();
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
      _note('Party look added', body: look.name, kind: 'look');
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
      _note('Reminder updated', body: event.title, kind: 'event');
    } else {
      events.add(event);
      _note('Reminder added', body: event.title, kind: 'event');
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
    if (eventId == officeAlarmId) {
      await startRinging(officeAlarmEvent);
      return;
    }
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
    if (event.id == officeAlarmId) {
      profile.officeAlarmFiredOn = dateKey(DateTime.now());
    } else {
      event.alarmFired = true;
    }
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
    final at = DateTime.now().add(Duration(minutes: minutes));
    if (event.id == officeAlarmId) {
      await scheduleEventAlarm(
        id: _officeSnoozeNotifId,
        at: at,
        title: 'Office day',
        body: 'Time to get ready',
        eventId: officeAlarmId,
      );
      return;
    }
    event
      ..at = at
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

  Future<void> _scheduleOfficeAlarms() async {
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      await cancelEventAlarm(officeNotifId(day));
    }
    await cancelEventAlarm(_officeSnoozeNotifId);
    if (profile.officeAlarmOn) {
      profile.officeAlarmOn = false;
      await _persist();
    }
  }

  Future<void> _resyncAlarms() async {
    for (final event in events) {
      if (event.alarmOn && !event.alarmFired && event.at.isAfter(DateTime.now())) {
        await _scheduleOne(event);
      }
    }
    await _scheduleOfficeAlarms();
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
      bucketList: bucketList,
    );
  }

  Future<Uint8List> buildExcelBackup() async {
    return encodeExcelBackup(
      profile: profile,
      garments: garments,
      week: week,
      events: events,
      partyLooks: partyLooks,
      completedDays: completedDays,
      clothSets: clothSets,
      bucketList: bucketList,
    );
  }

  Future<({int clothes, int looks, int events})> restoreBackup(
    Uint8List bytes,
  ) async {
    final packed = DrapeBackup.decode(bytes);
    final json = packed.json;
    final importedClothes = json['garments'] as List? ?? const [];
    if (!packed.hasProfile &&
        packed.imageFiles().isEmpty &&
        importedClothes.isEmpty) {
      throw const FormatException('This is not a Drape backup file.');
    }

    final usedKeys = <String>{};
    Future<String?> storePhoto(String? path, String id) async {
      final match = packed.matchFile(path, id: id);
      if (match == null || match.value.isEmpty) return null;
      usedKeys.add(match.key);
      return _store.saveImage(match.value, id);
    }

    if (packed.hasProfile) {
      final incoming = UserProfile.fromJson(
        json['profile'] as Map<String, dynamic>,
      );
      _mergeProfile(incoming);
      final photo = await storePhoto(incoming.photoPath, 'profile');
      if (photo != null) profile.photoPath = photo;
      final officeMusic = packed.fileFor(
        incoming.officeAlarmMusicPath,
        id: officeAlarmId,
      );
      if (officeMusic != null && officeMusic.isNotEmpty) {
        final ext = fileExt(incoming.officeAlarmMusicPath, fallback: 'mp3');
        profile.officeAlarmMusicPath = await _store.saveAudio(
          officeMusic,
          officeAlarmId,
          ext: ext,
          mime: audioMime(ext),
        );
        profile.officeAlarmMusicName = incoming.officeAlarmMusicName;
      }
      if (json['week'] != null) {
        week = WeekPlan.fromJson(json['week'] as Map<String, dynamic>);
      }
      completedDays.addAll(
        ((json['completedDays'] as List?) ?? const []).map((e) => e as String),
      );
      _upsertSets(
        ((json['clothSets'] as List?) ?? const [])
            .map((e) => ClothSet.fromJson(e as Map<String, dynamic>)),
      );
      _upsertBucket(
        ((json['bucketList'] as List?) ?? const []).map(
          (e) => StyleBucketItem.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    for (final raw in importedClothes) {
      final garment = Garment.fromJson(raw as Map<String, dynamic>);
      final photo = await storePhoto(garment.imagePath, garment.id);
      if (photo != null) {
        garment.imagePath = photo;
      } else {
        final existing = garmentById(garment.id);
        garment.imagePath = existing?.imagePath;
      }
      _upsertItem(garments, garment, (g) => g.id);
    }

    for (final entry in packed.imageFiles()) {
      final key = normalizeZipPath(entry.key);
      if (usedKeys.contains(key)) continue;
      final lower = key.toLowerCase();
      if (lower.contains('/party/') ||
          lower.contains('/music/') ||
          lower.contains('/profile/')) {
        continue;
      }
      final id = _uuid.v4();
      final name = zipBaseName(entry.key).replaceFirst(RegExp(r'\.[^.]+$'), '');
      usedKeys.add(key);
      garments.add(
        Garment(
          id: id,
          name: name.isEmpty ? 'Imported photo' : name,
          category: GarmentCategory.top,
          colors: const [0xFFD9C7B8],
          imagePath: await _store.saveImage(entry.value, id),
        ),
      );
    }

    for (final raw in (json['partyLooks'] as List? ?? const [])) {
      final look = PartyLook.fromJson(raw as Map<String, dynamic>);
      final photo = await storePhoto(look.imagePath, look.id);
      if (photo != null) {
        look.imagePath = photo;
      } else {
        look.imagePath = partyLookById(look.id)?.imagePath;
      }
      _upsertItem(partyLooks, look, (e) => e.id);
    }

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
        event.musicPath = eventById(event.id)?.musicPath;
      }
      _upsertItem(events, event, (e) => e.id);
    }

    _note(
      'Backup imported',
      body:
          'Added or updated ${importedClothes.length} clothes without replacing what you already have.',
      kind: 'import',
    );

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

  void _mergeProfile(UserProfile incoming) {
    if (incoming.name.trim().isNotEmpty) profile.name = incoming.name;
    profile.wearer = incoming.wearer;
    if (incoming.dateOfBirth != null) profile.dateOfBirth = incoming.dateOfBirth;
    if (incoming.heightCm != null) profile.heightCm = incoming.heightCm;
    if (incoming.weightKg != null) profile.weightKg = incoming.weightKg;
    if (incoming.description.trim().isNotEmpty) {
      profile.description = incoming.description;
    }
    if (incoming.workdays.isNotEmpty) profile.workdays = incoming.workdays;
    profile.workStyle = incoming.workStyle;
    profile.minRepeatDays = incoming.minRepeatDays;
    profile.officeAlarmOn = false;
    if (incoming.customShelves.isNotEmpty) {
      final seen = {
        for (final shelf in profile.customShelves) shelf.toLowerCase(),
      };
      for (final shelf in incoming.customShelves) {
        if (seen.add(shelf.toLowerCase())) {
          profile.customShelves = [...profile.customShelves, shelf];
        }
      }
    }
    profile.onboarded = true;
  }

  void _upsertSets(Iterable<ClothSet> incoming) {
    for (final set in incoming) {
      _upsertItem(clothSets, set, (e) => e.id);
    }
  }

  void _upsertBucket(Iterable<StyleBucketItem> incoming) {
    for (final item in incoming) {
      _upsertItem(bucketList, item, (e) => e.id);
    }
  }

  void _upsertItem<T>(
    List<T> list,
    T item,
    String Function(T value) idOf,
  ) {
    final id = idOf(item);
    final index = list.indexWhere((e) => idOf(e) == id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
  }
}
