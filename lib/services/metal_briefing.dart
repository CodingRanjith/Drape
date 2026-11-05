import 'package:shared_preferences/shared_preferences.dart';

import 'metal_prices.dart';

/// Morning gold and silver change vs the last saved day.
class MetalBriefingResult {
  const MetalBriefingResult({
    required this.title,
    required this.body,
    required this.gold22,
    required this.silver,
    required this.notified,
  });

  final String title;
  final String body;
  final double gold22;
  final double silver;
  final bool notified;
}

class MetalBriefing {
  MetalBriefing._();
  static final MetalBriefing instance = MetalBriefing._();

  static const payload = 'metal-briefing';
  static const notificationId = 9201;
  static const morningHour = 8;
  static const morningMinute = 0;

  static const _lastGoldKey = 'metal_brief_last_gold22';
  static const _lastSilverKey = 'metal_brief_last_silver';
  static const _lastDateKey = 'metal_brief_last_date';
  static const _priorGoldKey = 'metal_brief_prior_gold22';
  static const _priorSilverKey = 'metal_brief_prior_silver';
  static const _priorDateKey = 'metal_brief_prior_date';
  static const _notifiedKey = 'metal_brief_notified';

  /// Fetch today's Chennai rates, compare with the previous day, and
  /// return a ready-to-show message once per day.
  Future<MetalBriefingResult?> run({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    final already = prefs.getString(_notifiedKey);
    if (!force && already == today) return null;

    final quote = await MetalPrices.instance.fetch(force: true);
    final gold22 = quote.goldPerGram(22);
    final silver = quote.silver999InrPerGram;

    final lastDate = prefs.getString(_lastDateKey);
    final lastGold = prefs.getDouble(_lastGoldKey);
    final lastSilver = prefs.getDouble(_lastSilverKey);

    if (lastDate != null &&
        lastDate != today &&
        lastGold != null &&
        lastSilver != null) {
      // Roll yesterday's close into the prior slot.
      await prefs.setDouble(_priorGoldKey, lastGold);
      await prefs.setDouble(_priorSilverKey, lastSilver);
      await prefs.setString(_priorDateKey, lastDate);
    }

    await prefs.setDouble(_lastGoldKey, gold22);
    await prefs.setDouble(_lastSilverKey, silver);
    await prefs.setString(_lastDateKey, today);

    final priorGold = prefs.getDouble(_priorGoldKey);
    final priorSilver = prefs.getDouble(_priorSilverKey);
    final priorDate = prefs.getString(_priorDateKey);

    if (priorDate == null || priorGold == null || priorSilver == null) {
      return MetalBriefingResult(
        title: 'Gold & silver rates saved',
        body:
            'Gold 22K ${formatInr(gold22)}/g · Silver ${formatInr(silver)}/g. '
            'Tomorrow morning you will see the change.',
        gold22: gold22,
        silver: silver,
        notified: false,
      );
    }

    final goldLine = _changeLine('Gold 22K', gold22, priorGold);
    final silverLine = _changeLine('Silver', silver, priorSilver);
    await prefs.setString(_notifiedKey, today);
    return MetalBriefingResult(
      title: _title(gold22 - priorGold, silver - priorSilver),
      body: '$goldLine\n$silverLine',
      gold22: gold22,
      silver: silver,
      notified: true,
    );
  }

  /// Body for the standing 8 am reminder, using the last known close.
  Future<String> reminderBody() async {
    final prefs = await SharedPreferences.getInstance();
    final gold = prefs.getDouble(_lastGoldKey);
    final silver = prefs.getDouble(_lastSilverKey);
    if (gold == null || silver == null) {
      return 'Tap for today\'s gold and silver vs yesterday.';
    }
    return 'Yesterday · Gold 22K ${formatInr(gold)}/g · Silver ${formatInr(silver)}/g. '
        'Tap for today\'s move.';
  }

  String _title(double goldDiff, double silverDiff) {
    final goldUp = goldDiff > 0.5;
    final goldDown = goldDiff < -0.5;
    final silverUp = silverDiff > 0.5;
    final silverDown = silverDiff < -0.5;
    if ((goldUp || silverUp) && !(goldDown || silverDown)) {
      return 'Gold & silver up today';
    }
    if ((goldDown || silverDown) && !(goldUp || silverUp)) {
      return 'Gold & silver down today';
    }
    if ((goldUp && silverDown) || (goldDown && silverUp)) {
      return 'Gold & silver mixed today';
    }
    return 'Gold & silver unchanged';
  }

  String _changeLine(String label, double today, double yesterday) {
    final diff = today - yesterday;
    final price = formatInr(today);
    if (diff > 0.5) {
      return '$label $price/g · up ${formatInr(diff)}';
    }
    if (diff < -0.5) {
      return '$label $price/g · down ${formatInr(diff.abs())}';
    }
    return '$label $price/g · same as yesterday';
  }

  String _dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<String, dynamic>> exportState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'lastGold22': prefs.getDouble(_lastGoldKey),
      'lastSilver': prefs.getDouble(_lastSilverKey),
      'lastDate': prefs.getString(_lastDateKey),
      'priorGold22': prefs.getDouble(_priorGoldKey),
      'priorSilver': prefs.getDouble(_priorSilverKey),
      'priorDate': prefs.getString(_priorDateKey),
      'notified': prefs.getString(_notifiedKey),
    };
  }

  Future<void> importState(Map<String, dynamic>? raw) async {
    if (raw == null) return;
    final prefs = await SharedPreferences.getInstance();
    Future<void> putDouble(String key, Object? value) async {
      if (value is num) await prefs.setDouble(key, value.toDouble());
    }

    Future<void> putString(String key, Object? value) async {
      if (value is String && value.isNotEmpty) {
        await prefs.setString(key, value);
      }
    }

    await putDouble(_lastGoldKey, raw['lastGold22']);
    await putDouble(_lastSilverKey, raw['lastSilver']);
    await putString(_lastDateKey, raw['lastDate']);
    await putDouble(_priorGoldKey, raw['priorGold22']);
    await putDouble(_priorSilverKey, raw['priorSilver']);
    await putString(_priorDateKey, raw['priorDate']);
    await putString(_notifiedKey, raw['notified']);
  }
}
