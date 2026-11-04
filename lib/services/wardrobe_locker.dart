import 'package:shared_preferences/shared_preferences.dart';

/// Persists a 4-digit wardrobe PIN and locked state.
class WardrobeLocker {
  WardrobeLocker._();
  static final WardrobeLocker instance = WardrobeLocker._();

  static const _pinKey = 'wardrobe_locker_pin';
  static const _lockedKey = 'wardrobe_locker_locked';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> hasPin() async {
    final pin = (await _prefs).getString(_pinKey);
    return pin != null && pin.length == 4;
  }

  Future<bool> isLocked() async {
    final p = await _prefs;
    final pin = p.getString(_pinKey);
    if (pin == null || pin.length != 4) return false;
    return p.getBool(_lockedKey) ?? false;
  }

  Future<void> setPin(String pin) async {
    assert(pin.length == 4);
    final p = await _prefs;
    await p.setString(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = (await _prefs).getString(_pinKey);
    return saved != null && saved == pin;
  }

  Future<void> lock() async {
    await (await _prefs).setBool(_lockedKey, true);
  }

  Future<void> unlock() async {
    await (await _prefs).setBool(_lockedKey, false);
  }

  Future<void> clear() async {
    final p = await _prefs;
    await p.remove(_pinKey);
    await p.remove(_lockedKey);
  }
}
