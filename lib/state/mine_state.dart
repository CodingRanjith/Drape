import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/app_store.dart';
import '../data/backup.dart';
import '../data/excel_backup.dart';
import '../data/media_bytes.dart';
import '../data/persist_image.dart';
import '../logic/stylist.dart';
import '../models/bucket_list.dart';
import '../models/jewelry.dart';
import '../models/life.dart';
import '../models/notice.dart';
import '../models/wardrobe.dart';
import '../services/alarm_tone.dart';
import '../services/metal_briefing.dart';
import '../services/notify.dart';
import '../services/store_browser_session.dart';
import '../services/wardrobe_decor_store.dart';
import '../services/wardrobe_locker.dart';

class MineState extends ChangeNotifier {
  MineState({AppStore? store, Stylist? stylist})
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
  /// Active calendar week (this Monday–Sunday).
  WeekPlan? week;
  /// Extra weeks the user planned (e.g. next week) — kept when the calendar rolls.
  List<WeekPlan> otherWeeks = [];
  /// Week currently shown on the Week tab (for Suggest / Add / Edit).
  DateTime visibleWeekStart = mondayOf(DateTime.now());
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
      otherWeeks = data.otherWeeks;
      events = data.events;
      partyLooks = data.partyLooks;
      completedDays = {...data.completedDays};
      clothSets = data.clothSets;
      bucketList = data.bucketList;
      notices = data.notices;
      _normalizeShelfIndices();
      _ensureCurrentWeek();
      _syncCompletedFromWeek();
    } catch (e, st) {
      debugPrint('Mine boot failed: $e\n$st');
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
      debugPrint('Mine persist failed: $e\n$st');
    }
    _alarmWatch?.cancel();
    _alarmWatch = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_checkDueAlarms());
      unawaited(_checkWaterReminder());
    });
    unawaited(_checkDueAlarms());
    unawaited(_checkWaterReminder());
  }

  /// Morning gold/silver vs yesterday. Runs once a day after 8 am, or on tap.
  Future<void> runMetalBriefing({bool force = false}) async {
    final now = DateTime.now();
    final morningReached = now.hour > MetalBriefing.morningHour ||
        (now.hour == MetalBriefing.morningHour &&
            now.minute >= MetalBriefing.morningMinute);
    if (!force && !morningReached) {
      await _scheduleMetalReminder();
      return;
    }
    try {
      final result = await MetalBriefing.instance.run(force: force);
      await _scheduleMetalReminder();
      if (result == null) return;
      if (result.notified || force) {
        await showLocalNotice(
          id: MetalBriefing.notificationId,
          title: result.title,
          body: result.body,
          payload: MetalBriefing.payload,
        );
      }
      if (result.notified) {
        _note(result.title, body: result.body, kind: 'metal');
        notifyListeners();
        await _persist();
      }
    } catch (e, st) {
      debugPrint('Metal briefing failed: $e\n$st');
      await _scheduleMetalReminder();
    }
  }

  Future<void> _scheduleMetalReminder() async {
    final body = await MetalBriefing.instance.reminderBody();
    await scheduleDailyMetalBriefing(
      id: MetalBriefing.notificationId + 1,
      hour: MetalBriefing.morningHour,
      minute: MetalBriefing.morningMinute,
      title: 'Gold & silver rates',
      body: body,
      payload: MetalBriefing.payload,
    );
  }

  @override
  void dispose() {
    _alarmWatch?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  WeekPlan _emptyWeek(DateTime weekStart) {
    final start = mondayOf(weekStart);
    return WeekPlan(
      weekStart: start,
      days: List.generate(
        7,
        (i) => DayPlan(date: start.add(Duration(days: i))),
      ),
    );
  }

  WeekPlan _buildWeek(DateTime weekStart) {
    final start = mondayOf(weekStart);
    if (_stylist.canDress(garments)) {
      return _stylist.planWeek(
        wardrobe: garments,
        profile: profile,
        weekStart: start,
      );
    }
    return _emptyWeek(start);
  }

  void _upsertOtherWeek(WeekPlan plan) {
    final start = mondayOf(plan.weekStart);
    otherWeeks.removeWhere((w) => sameDay(w.weekStart, start));
    otherWeeks.add(plan);
  }

  WeekPlan? _takeOtherWeek(DateTime weekStart) {
    final start = mondayOf(weekStart);
    final index = otherWeeks.indexWhere((w) => sameDay(w.weekStart, start));
    if (index < 0) return null;
    return otherWeeks.removeAt(index);
  }

  /// Week plan that contains [date], if any (current or stored next/past weeks).
  WeekPlan? weekPlanFor(DateTime date) {
    final start = mondayOf(date);
    if (week != null && sameDay(week!.weekStart, start)) return week;
    for (final w in otherWeeks) {
      if (sameDay(w.weekStart, start)) return w;
    }
    return null;
  }

  DayPlan? dayPlanFor(DateTime date) => weekPlanFor(date)?.forDate(date);

  /// Ensures Mon–Sun day plans exist for the week of [date] so Add/Edit work.
  WeekPlan ensureWeek(DateTime date, {bool autoSuggest = false}) {
    final start = mondayOf(date);
    final currentStart = mondayOf(DateTime.now());
    final existing = weekPlanFor(start);
    if (existing != null) {
      if (autoSuggest) _suggestWeekFromSets(existing, reshuffle: false);
      return existing;
    }
    final plan = autoSuggest ? _buildWeek(start) : _emptyWeek(start);
    if (sameDay(start, currentStart)) {
      week = plan;
    } else {
      _upsertOtherWeek(plan);
    }
    if (autoSuggest) _suggestWeekFromSets(plan, reshuffle: false);
    return plan;
  }

  /// Create/load a week plan and persist so next week Add/Edit survives restarts.
  Future<WeekPlan> ensureWeekSaved(
    DateTime date, {
    bool autoSuggest = false,
  }) async {
    final plan = ensureWeek(date, autoSuggest: autoSuggest);
    visibleWeekStart = mondayOf(date);
    notifyListeners();
    await _persist();
    return plan;
  }

  void setVisibleWeek(DateTime date) {
    visibleWeekStart = mondayOf(date);
  }

  void _ensureCurrentWeek() {
    final start = mondayOf(DateTime.now());
    if (week != null && !sameDay(week!.weekStart, start)) {
      // Keep last week's looks when the calendar rolls forward.
      _upsertOtherWeek(week!);
      week = _takeOtherWeek(start);
    }
    week ??= _buildWeek(start);
    _suggestWeekFromSets(week!, reshuffle: false);
  }

  void _syncCompletedFromWeek() {
    void sync(WeekPlan? plan) {
      if (plan == null) return;
      for (final day in plan.days) {
        if (day.worn) completedDays.add(dateKey(day.date));
      }
    }

    sync(week);
    for (final w in otherWeeks) {
      sync(w);
    }
  }

  Future<void> _persist() => _store.save(
    profile: profile,
    garments: garments,
    week: week,
    otherWeeks: otherWeeks,
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

  Future<void> completeIntroVideo() async {
    profile.introVideoSeen = true;
    notifyListeners();
    await _persist();
  }

  Future<void> setIntroVideoLang(String lang) async {
    final next = lang == 'ta' ? 'ta' : 'en';
    if (profile.introVideoLang == next) return;
    profile.introVideoLang = next;
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
      ..onboarded = true
      ..introVideoSeen = false;
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
    otherWeeks = [];
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

  bool _ensureWaterDay() {
    final today = dateKey(DateTime.now());
    if (profile.waterDrunkDay == today) return false;
    profile.waterDrunkDay = today;
    profile.waterGlassesDrunk = 0;
    profile.waterAwaitingDrink = false;
    return true;
  }

  String _waterProgressLabel() {
    _ensureWaterDay();
    return '${profile.waterGlassesDrunk}/${profile.waterGlassesGoal} glasses';
  }

  String _waterMotivateBody() {
    final left =
        (profile.waterGlassesGoal - profile.waterGlassesDrunk).clamp(0, 99);
    final tip = _waterMotivate[DateTime.now().minute % _waterMotivate.length];
    return '$tip\n$_waterProgressLabel() · $left left today.';
  }

  Future<void> saveWaterReminder({
    required int glassesPerDay,
    required int intervalHours,
    bool enabled = true,
  }) async {
    final glasses = glassesPerDay.clamp(1, 20);
    final hours = intervalHours.clamp(1, 12);
    _ensureWaterDay();
    profile
      ..waterReminderOn = enabled
      ..waterGlassesGoal = glasses
      ..waterIntervalHours = hours
      ..waterAwaitingDrink = false;
    if (profile.waterGlassesDrunk > glasses) {
      profile.waterGlassesDrunk = glasses;
    }
    await cancelEventAlarm(waterScheduleId);
    await cancelEventAlarm(waterNotifId);
    if (!enabled) {
      profile.waterNextAtTime = null;
      notifyListeners();
      await _persist();
      return;
    }
    if (profile.waterGoalMet) {
      profile.waterNextAtTime = null;
      notifyListeners();
      await _persist();
      _note(
        'Water goal ready',
        body: 'Already done for today · $glasses glasses',
        kind: 'water',
      );
      return;
    }
    final next = DateTime.now().add(Duration(hours: hours));
    profile.waterNextAtTime = next;
    notifyListeners();
    await _persist();
    await _scheduleNextWaterReminder();
    _note(
      'Water reminder on',
      body: '$glasses glasses/day · every ${hours}h',
      kind: 'water',
    );
  }

  Future<void> markWaterDrunk() async {
    _ensureWaterDay();
    if (!profile.waterReminderOn) return;
    if (profile.waterGoalMet) {
      profile.waterAwaitingDrink = false;
      await cancelEventAlarm(waterNotifId);
      notifyListeners();
      await _persist();
      return;
    }
    profile.waterGlassesDrunk += 1;
    profile.waterAwaitingDrink = false;
    await cancelEventAlarm(waterNotifId);
    if (profile.waterGoalMet) {
      profile.waterNextAtTime = null;
      await cancelEventAlarm(waterScheduleId);
      notifyListeners();
      await _persist();
      _note(
        'Water goal done!',
        body: 'All ${profile.waterGlassesGoal} glasses today — nice work.',
        kind: 'water',
      );
      return;
    }
    final next =
        DateTime.now().add(Duration(hours: profile.waterIntervalHours));
    profile.waterNextAtTime = next;
    notifyListeners();
    await _persist();
    await _scheduleNextWaterReminder();
    _note(
      'Glass logged',
      body: _waterProgressLabel(),
      kind: 'water',
    );
  }

  Future<void> _scheduleNextWaterReminder() async {
    await cancelEventAlarm(waterScheduleId);
    if (!profile.waterReminderOn || profile.waterGoalMet) return;
    final at = profile.waterNextAtTime;
    if (at == null) return;
    await scheduleWaterReminder(
      id: waterScheduleId,
      at: at,
      title: 'Drink water',
      body: _waterMotivateBody(),
      payload: waterReminderId,
    );
  }

  Future<void> _fireWaterReminder({bool forceNotice = true}) async {
    _ensureWaterDay();
    if (!profile.waterReminderOn || profile.waterGoalMet) return;
    if (profile.waterAwaitingDrink && !forceNotice) return;
    profile.waterAwaitingDrink = true;
    // Hold next until user logs the glass (or until they change settings).
    profile.waterNextAtTime = null;
    await cancelEventAlarm(waterScheduleId);
    notifyListeners();
    await _persist();
    final title = 'Drink water';
    final body = _waterMotivateBody();
    // Post OS notice for due checks / web. Scheduled OS alarm already shows one;
    // notification tap uses forceNotice:false to avoid a duplicate flash.
    if (forceNotice || kIsWeb) {
      await showWaterReminderNotice(
        id: waterNotifId,
        title: title,
        body: body,
        payload: waterReminderId,
      );
    }
    _note(title, body: body, kind: 'water');
    unawaited(_playWaterSound());
  }

  /// Call after [initEventAlarms] so water/event schedules land while notify is ready.
  Future<void> onNotificationsReady() async {
    await _resyncAlarms();
    await _checkWaterReminder(nudgeAwaiting: true);
  }

  Future<void> _playWaterSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(1);
      await _player.play(AssetSource('sounds/water_chime.wav'));
    } catch (_) {
      try {
        await _player.play(BytesSource(buildWaterWav()));
      } catch (e) {
        debugPrint('Water sound failed: $e');
      }
    }
  }

  Future<void> _checkWaterReminder({bool nudgeAwaiting = false}) async {
    await _consumePendingWaterDrank();
    if (_ensureWaterDay()) {
      notifyListeners();
      if (profile.waterReminderOn && !profile.waterGoalMet) {
        profile.waterNextAtTime = DateTime.now().add(
          Duration(hours: profile.waterIntervalHours),
        );
        await _persist();
        await _scheduleNextWaterReminder();
      } else {
        await _persist();
      }
    }
    if (!profile.waterReminderOn || profile.waterGoalMet) return;
    // Awaiting a glass — only re-show on resume / after notify init (not every timer tick).
    if (profile.waterAwaitingDrink) {
      if (nudgeAwaiting) {
        await showWaterReminderNotice(
          id: waterNotifId,
          title: 'Drink water',
          body: _waterMotivateBody(),
          payload: waterReminderId,
        );
      }
      return;
    }
    final next = profile.waterNextAtTime;
    if (next == null) {
      // Reminder on but no next time — start a fresh interval from now.
      profile.waterNextAtTime = DateTime.now().add(
        Duration(hours: profile.waterIntervalHours),
      );
      await _persist();
      await _scheduleNextWaterReminder();
      return;
    }
    if (next.isAfter(DateTime.now())) return;
    await _fireWaterReminder(forceNotice: true);
  }

  Future<void> _consumePendingWaterDrank() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(pendingWaterDrankKey) != true) return;
      await prefs.setBool(pendingWaterDrankKey, false);
      await markWaterDrunk();
    } catch (_) {}
  }

  Future<void> addCustomShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    final exists = profile.customShelves.any(
      (e) => e.toLowerCase() == label.toLowerCase(),
    );
    if (exists) return;
    profile.customShelves = [...profile.customShelves, label];
    final order = List<String>.from(orderedShelfLabels);
    order.removeWhere((e) => e.toLowerCase() == label.toLowerCase());
    order.add(label);
    profile.shelfOrder = order;
    notifyListeners();
    await _persist();
  }

  bool _isHiddenLabel(String label) => profile.hiddenShelves.any(
        (e) => e.toLowerCase() == label.toLowerCase(),
      );

  /// Built-in + custom shelf labels in the user's preferred order (not hidden).
  List<String> get orderedShelfLabels {
    final defaults =
        profile.wearer.wardrobeCategories.map((c) => c.label).toList();
    final customs = profile.customShelves;
    final known = <String>{
      for (final d in defaults) d,
      for (final c in customs) c,
    };
    final ordered = <String>[];
    for (final label in profile.shelfOrder) {
      if (known.remove(label)) ordered.add(label);
    }
    for (final label in defaults) {
      if (known.remove(label)) ordered.add(label);
    }
    for (final label in customs) {
      if (known.remove(label)) ordered.add(label);
    }
    return ordered.where((e) => !_isHiddenLabel(e)).toList();
  }

  /// Built-in categories the user deleted (can restore).
  List<String> get hiddenBuiltinShelves {
    final builtins = {
      for (final c in profile.wearer.wardrobeCategories) c.label,
    };
    return profile.hiddenShelves
        .where((e) => builtins.contains(e))
        .toList();
  }

  Future<void> setShelfOrder(List<String> order) async {
    profile.shelfOrder = List<String>.from(order);
    notifyListeners();
    await _persist();
  }

  /// Delete a category: removes custom, or hides a built-in.
  Future<void> deleteShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    final isCustom = profile.customShelves.any(
      (e) => e.toLowerCase() == label.toLowerCase(),
    );
    if (isCustom) {
      await removeCustomShelf(label);
      return;
    }
    final isBuiltin = profile.wearer.wardrobeCategories.any(
      (c) => c.label.toLowerCase() == label.toLowerCase(),
    );
    if (!isBuiltin) return;
    if (!_isHiddenLabel(label)) {
      profile.hiddenShelves = [...profile.hiddenShelves, label];
    }
    profile.shelfOrder = profile.shelfOrder
        .where((e) => e.toLowerCase() != label.toLowerCase())
        .toList();
    notifyListeners();
    await _persist();
  }

  Future<void> restoreShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    profile.hiddenShelves = profile.hiddenShelves
        .where((e) => e.toLowerCase() != label.toLowerCase())
        .toList();
    final order = List<String>.from(orderedShelfLabels);
    if (!order.any((e) => e.toLowerCase() == label.toLowerCase())) {
      order.add(label);
    }
    profile.shelfOrder = order;
    notifyListeners();
    await _persist();
  }

  Future<void> removeCustomShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    final before = profile.customShelves.length;
    profile.customShelves = profile.customShelves
        .where((e) => e.toLowerCase() != label.toLowerCase())
        .toList();
    if (profile.customShelves.length == before) return;
    profile.shelfOrder = profile.shelfOrder
        .where((e) => e.toLowerCase() != label.toLowerCase())
        .toList();
    // Keep garments; clear custom shelf so they fall under Accessories.
    for (final g in garments) {
      final custom = g.customShelf?.trim();
      if (custom != null && custom.toLowerCase() == label.toLowerCase()) {
        g.customShelf = null;
        g.wardrobeCategory = WardrobeCategory.accessories;
        g.category = GarmentCategory.accessory;
      }
    }
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
    return piecesOf(dayPlanFor(date)?.outfit);
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
  static const waterReminderId = 'water-reminder';
  static const waterNotifId = 9301;
  static const waterScheduleId = 9302;

  static const _waterMotivate = [
    'Time for a glass — your body will thank you.',
    'Sip time! Stay fresh and focused.',
    'Hydration check — grab a glass of water.',
    'One glass closer to your goal. You’ve got this!',
    'Pause and drink — energy loves water.',
  ];
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

  /// Keep each shelf's pieces in a stable left→right order.
  void _normalizeShelfIndices() {
    final byShelf = <String, List<Garment>>{};
    for (final g in garments) {
      byShelf.putIfAbsent(g.shelfLabel, () => []).add(g);
    }
    for (final list in byShelf.values) {
      list.sort((a, b) {
        final byIndex = a.shelfIndex.compareTo(b.shelfIndex);
        if (byIndex != 0) return byIndex;
        return a.createdAt.compareTo(b.createdAt);
      });
      for (var i = 0; i < list.length; i++) {
        list[i].shelfIndex = i;
      }
    }
  }

  List<Garment> garmentsOnShelf(String shelfLabel) {
    final list = garments.where((g) => g.shelfLabel == shelfLabel).toList()
      ..sort((a, b) {
        final byIndex = a.shelfIndex.compareTo(b.shelfIndex);
        if (byIndex != 0) return byIndex;
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  Future<void> reorderShelfGarments(
    String shelfLabel,
    int oldIndex,
    int newIndex,
  ) async {
    final list = garmentsOnShelf(shelfLabel);
    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex > list.length ||
        oldIndex == newIndex) {
      return;
    }
    // Classic ReorderableListView.onReorder: adjust when moving down.
    var target = newIndex;
    if (oldIndex < target) target -= 1;
    final moved = list.removeAt(oldIndex);
    target = target.clamp(0, list.length);
    list.insert(target, moved);
    for (var i = 0; i < list.length; i++) {
      list[i].shelfIndex = i;
    }
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
      final peers = garmentsOnShelf(garment.shelfLabel);
      garment.shelfIndex =
          peers.isEmpty ? 0 : peers.map((g) => g.shelfIndex).reduce(
                    (a, b) => a > b ? a : b,
                  ) +
              1;
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
    void scrub(WeekPlan? plan) {
      if (plan == null) return;
      for (final day in plan.days) {
        day.outfit?.removePieceId(id);
      }
    }

    scrub(week);
    for (final w in otherWeeks) {
      scrub(w);
    }
    for (final set in clothSets) {
      set.outfit.removePieceId(id);
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

  void regenerateWeek({bool keepLocks = true, DateTime? weekStart}) {
    final start = mondayOf(weekStart ?? DateTime.now());
    final currentStart = mondayOf(DateTime.now());
    final existing = weekPlanFor(start);
    final planned = _stylist.planWeek(
      wardrobe: garments,
      profile: profile,
      weekStart: start,
      existing: keepLocks ? existing : null,
    );
    if (sameDay(start, currentStart)) {
      week = planned;
    } else {
      _upsertOtherWeek(planned);
    }
    todayIndex = 0;
    _suggestWeekFromSets(planned, reshuffle: false);
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
    final sets = [
      for (final set in readyClothSets) set.outfit.copy(id: _uuid.v4()),
    ];
    // Prefer collection sets when there are enough for a full week.
    if (sets.length >= 7) return sets;
    return [...sets, ...readyDressLooks];
  }

  int get suggestableLookCount => _suggestableLooks.length;

  int get readySetCount => readyClothSets.length;

  /// Randomly fills Mon–Sun from uploaded sets.
  /// - Need **7+** looks to auto-suggest.
  /// - With **14+** looks, [reshuffle] assigns a fresh different set each day.
  void _suggestWeekFromSets(WeekPlan plan, {required bool reshuffle}) {
    final looks = [..._suggestableLooks];
    if (looks.length < 7) return;

    looks.shuffle();
    final picks = looks.take(7).toList();

    for (var i = 0; i < plan.days.length; i++) {
      final day = plan.days[i];
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

  Future<void> suggestWeekSets({
    bool reshuffle = false,
    DateTime? weekStart,
  }) async {
    final plan = ensureWeek(weekStart ?? DateTime.now());
    final force = reshuffle || readySetCount >= 14 || suggestableLookCount >= 14;
    _suggestWeekFromSets(plan, reshuffle: force);
    notifyListeners();
    await _persist();
  }

  Future<bool> assignSetToDay(DayPlan day, ClothSet set) async {
    ensureWeek(day.date);
    final ids = set.outfit.pieceIds;
    for (final id in ids) {
      if (isUsedElsewhereThisWeek(id, except: day)) return false;
    }
    day.outfit = set.outfit.copy(id: _uuid.v4());
    // Keep the user's pick fixed — auto-suggest skips locked days.
    day.locked = true;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Build a day look from wardrobe piece ids (no style collection needed).
  Future<bool> assignPiecesToDay(DayPlan day, List<String> garmentIds) async {
    ensureWeek(day.date);
    if (garmentIds.isEmpty) return false;
    for (final id in garmentIds) {
      if (isUsedElsewhereThisWeek(id, except: day)) return false;
    }
    final outfit = Outfit(id: _uuid.v4());
    for (final id in garmentIds) {
      final garment = garmentById(id);
      if (garment == null) continue;
      _putGarmentOnOutfit(outfit, garment);
    }
    if (outfit.pieceIds.isEmpty) return false;
    day.outfit = outfit;
    day.locked = true;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> assignDressToDay(DayPlan day, Garment dress) async {
    ensureWeek(day.date);
    if (dress.category != GarmentCategory.dress) return false;
    if (isUsedElsewhereThisWeek(dress.id, except: day)) return false;
    day.outfit = Outfit(id: _uuid.v4(), dressId: dress.id);
    day.locked = true;
    notifyListeners();
    await _persist();
    return true;
  }

  List<ClothSet> availableSetsForDay(DayPlan day) {
    final used = _usedIds(except: day);
    return readyClothSets.where((set) {
      return set.outfit.pieceIds.every((id) => !used.contains(id));
    }).toList();
  }

  List<Garment> availableDressesForDay(DayPlan day) {
    final used = _usedIds(except: day);
    return garments
        .where(
          (g) =>
              g.category == GarmentCategory.dress &&
              !g.inLaundry &&
              g.imagePath != null &&
              g.imagePath!.trim().isNotEmpty &&
              !used.contains(g.id),
        )
        .toList();
  }

  List<Garment> optionsFor(ClothesType type) {
    return garments
        .where((g) => !g.inLaundry && !Jewelry.isPiece(g) && type.matches(g))
        .toList();
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
    if (day == null || day.worn) return;
    if (todayChoices.isEmpty) _rebuildTodayChoices();
    if (todayChoices.isEmpty) {
      await shuffleDay(day);
      return;
    }
    todayIndex = (todayIndex + 1) % todayChoices.length;
    // Replace today’s week look (even if a set was already saved).
    day.outfit = todayChoices[todayIndex];
    day.locked = false;
    notifyListeners();
    await _persist();
  }

  Future<void> showPreviousLook() async {
    final day = todayPlan;
    if (day == null || day.worn) return;
    if (todayChoices.isEmpty) _rebuildTodayChoices();
    if (todayChoices.isEmpty) return;
    todayIndex = (todayIndex - 1 + todayChoices.length) % todayChoices.length;
    day.outfit = todayChoices[todayIndex];
    day.locked = false;
    notifyListeners();
    await _persist();
  }

  /// Save the current look onto today’s week day (replaces any prior set).
  Future<void> saveTodayLook() async {
    final day = todayPlan;
    if (day == null || day.outfit == null || day.outfit!.isEmpty) return;
    day.locked = true;
    _note(
      "Today's look saved",
      body: 'This outfit is set for today in your week plan.',
      kind: 'outfit',
    );
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
    ensureWeek(day.date);
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
    day.locked = false;
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
    if (!outfit.removePieceId(garment.id)) return;
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

  Future<ClothSet> addClothSet(
    StyleCollection collection, {
    String? name,
    List<String> garmentIds = const [],
  }) async {
    final set = ClothSet(
      id: _uuid.v4(),
      name: (name == null || name.trim().isEmpty)
          ? 'Set ${setsFor(collection).length + 1}'
          : name.trim(),
      collection: collection,
    );
    for (final id in garmentIds) {
      final garment = garmentById(id);
      if (garment == null) continue;
      _putGarmentOnOutfit(set.outfit, garment);
    }
    clothSets.add(set);
    if (week != null) _suggestWeekFromSets(week!, reshuffle: false);
    notifyListeners();
    await _persist();
    return set;
  }

  Future<void> replaceClothSetPieces(
    String setId, {
    String? name,
    required List<String> garmentIds,
  }) async {
    final set = clothSetById(setId);
    if (set == null) return;
    if (name != null) {
      final next = name.trim();
      if (next.isNotEmpty) set.name = next;
    }
    set.outfit = Outfit(id: set.id);
    for (final id in garmentIds) {
      final garment = garmentById(id);
      if (garment == null) continue;
      _putGarmentOnOutfit(set.outfit, garment);
    }
    if (week != null) _suggestWeekFromSets(week!, reshuffle: false);
    notifyListeners();
    await _persist();
  }

  /// Wardrobe shelves that currently have at least one item.
  List<({String label, List<Garment> items})> populatedShelves() {
    final byShelf = <String, List<Garment>>{};
    for (final garment in garments) {
      byShelf.putIfAbsent(garment.shelfLabel, () => []).add(garment);
    }
    final rows = <({String label, List<Garment> items})>[];
    for (final category in profile.wearer.wardrobeCategories) {
      final items = byShelf.remove(category.label);
      if (items == null || items.isEmpty) continue;
      rows.add((label: category.label, items: items));
    }
    for (final custom in profile.customShelves) {
      final items = byShelf.remove(custom);
      if (items == null || items.isEmpty) continue;
      rows.add((label: custom, items: items));
    }
    for (final entry in byShelf.entries) {
      if (entry.value.isEmpty) continue;
      rows.add((label: entry.key, items: entry.value));
    }
    return rows;
  }

  void _putGarmentOnOutfit(Outfit outfit, Garment garment) {
    final asTshirt = garment.category == GarmentCategory.top &&
        garment.topKind == TopKind.tshirt;
    outfit.addPieceId(
      garment.id,
      category: garment.category,
      asTshirt: asTshirt,
    );
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
    Uint8List? imageBytes,
  }) async {
    final id = _uuid.v4();
    String? imagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      imagePath = await _store.saveImage(imageBytes, id);
    }
    final item = StyleBucketItem(
      id: id,
      title: title.trim().isEmpty ? 'New style dream' : title.trim(),
      note: note.trim(),
      vibe: vibe,
      imagePath: imagePath,
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
    Uint8List? imageBytes,
    bool clearImage = false,
  }) async {
    final item = bucketById(id);
    if (item == null) return;
    if (title != null) {
      final next = title.trim();
      if (next.isNotEmpty) item.title = next;
    }
    if (note != null) item.note = note.trim();
    if (vibe != null) item.vibe = vibe;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      item.imagePath = await _store.saveImage(imageBytes, item.id);
    } else if (clearImage) {
      item.imagePath = null;
    }
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
    if (garmentId == null) {
      _putOnOutfit(set.outfit, category, null);
    } else {
      final garment = garmentById(garmentId);
      if (garment == null) return;
      _putGarmentOnOutfit(set.outfit, garment);
    }
    if (week != null) _suggestWeekFromSets(week!, reshuffle: false);
    notifyListeners();
    await _persist();
  }

  Future<void> removeFromClothSet(String setId, Garment garment) async {
    final set = clothSetById(setId);
    if (set == null) return;
    if (!set.outfit.removePieceId(garment.id)) return;
    if (week != null) _suggestWeekFromSets(week!, reshuffle: false);
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
    final plan = except != null ? weekPlanFor(except.date) : week;
    if (plan == null) return ids;
    for (final day in plan.days) {
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

  Future<void> checkWaterReminder({bool nudgeAwaiting = false}) =>
      _checkWaterReminder(nudgeAwaiting: nudgeAwaiting);

  Future<void> handleAlarm(String eventId) async {
    if (eventId == MetalBriefing.payload) {
      await runMetalBriefing(force: true);
      return;
    }
    if (eventId == waterDrankPayload || eventId == 'water-drank') {
      await markWaterDrunk();
      return;
    }
    if (eventId == waterReminderId || eventId == waterReminderPayload) {
      // OS already displayed the scheduled notice — mark awaiting without a duplicate.
      await _fireWaterReminder(forceNotice: false);
      return;
    }
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
    _ensureWaterDay();
    if (profile.waterReminderOn &&
        !profile.waterGoalMet &&
        profile.waterNextAtTime != null) {
      await _scheduleNextWaterReminder();
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
    return MineBackup.encode(
      profile: profile,
      garments: garments,
      week: week,
      otherWeeks: otherWeeks,
      events: events,
      partyLooks: partyLooks,
      completedDays: completedDays,
      clothSets: clothSets,
      bucketList: bucketList,
      notices: notices,
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
      notices: notices,
      wardrobeDecor: await WardrobeDecorController.exportAll(),
      wardrobeLocker: await WardrobeLocker.instance.exportState(),
      metalBriefing: await MetalBriefing.instance.exportState(),
      ecommerceSessions: await StoreBrowserSession.exportAll(),
    );
  }

  Future<({int clothes, int looks, int events})> restoreBackup(
    Uint8List bytes,
  ) async {
    final packed = MineBackup.decode(bytes);
    final json = packed.json;
    final importedClothes = json['garments'] as List? ?? const [];
    if (!packed.hasProfile &&
        packed.imageFiles().isEmpty &&
        importedClothes.isEmpty) {
      throw const FormatException('This is not a Mine backup file.');
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
      otherWeeks = ((json['otherWeeks'] as List?) ?? const [])
          .map((e) => WeekPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      completedDays.addAll(
        ((json['completedDays'] as List?) ?? const []).map((e) => e as String),
      );
      _upsertSets(
        ((json['clothSets'] as List?) ?? const [])
            .map((e) => ClothSet.fromJson(e as Map<String, dynamic>)),
      );
      for (final raw in ((json['bucketList'] as List?) ?? const [])) {
        final item = StyleBucketItem.fromJson(raw as Map<String, dynamic>);
        final photo = await storePhoto(item.imagePath, item.id);
        if (photo != null) {
          item.imagePath = photo;
        } else {
          item.imagePath = bucketById(item.id)?.imagePath;
        }
        _upsertItem(bucketList, item, (e) => e.id);
      }
      for (final raw in ((json['notices'] as List?) ?? const [])) {
        final notice = AppNotice.fromJson(raw as Map<String, dynamic>);
        _upsertItem(notices, notice, (e) => e.id);
      }
    }

    await WardrobeDecorController.importAll(
      json['wardrobeDecor'] as List?,
    );
    await WardrobeLocker.instance.importState(
      json['wardrobeLocker'] is Map
          ? Map<String, dynamic>.from(json['wardrobeLocker'] as Map)
          : null,
    );
    await MetalBriefing.instance.importState(
      json['metalBriefing'] is Map
          ? Map<String, dynamic>.from(json['metalBriefing'] as Map)
          : null,
    );
    await StoreBrowserSession.importAll(
      json['ecommerceSessions'] as List?,
    );

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
          lower.contains('/profile/') ||
          lower.contains('/bucket/')) {
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
    profile.officeAlarmOn = incoming.officeAlarmOn;
    profile.officeAlarmHour = incoming.officeAlarmHour;
    profile.officeAlarmMinute = incoming.officeAlarmMinute;
    if (incoming.officeAlarmMusicName != null) {
      profile.officeAlarmMusicName = incoming.officeAlarmMusicName;
    }
    profile.walkthroughSeen =
        profile.walkthroughSeen || incoming.walkthroughSeen;
    // Imported profiles already know the app — skip intro video.
    profile.introVideoSeen = true;
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
    if (incoming.shelfOrder.isNotEmpty) {
      profile.shelfOrder = List<String>.from(incoming.shelfOrder);
    }
    if (incoming.hiddenShelves.isNotEmpty) {
      final seen = {
        for (final shelf in profile.hiddenShelves) shelf.toLowerCase(),
      };
      for (final shelf in incoming.hiddenShelves) {
        if (seen.add(shelf.toLowerCase())) {
          profile.hiddenShelves = [...profile.hiddenShelves, shelf];
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
