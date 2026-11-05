import 'package:shared_preferences/shared_preferences.dart';

/// Remembers login and the last useful page for each ecommerce store.
class StoreBrowserSession {
  StoreBrowserSession._();

  static String _urlKey(String storeId) => 'ecom_last_url_$storeId';
  static String _loggedKey(String storeId) => 'ecom_logged_$storeId';

  static bool looksLikeLogin(String url) {
    final value = url.toLowerCase();
    return value.contains('login') ||
        value.contains('signin') ||
        value.contains('sign-in') ||
        value.contains('sign_in') ||
        value.contains('/ap/signin') ||
        value.contains('/auth') ||
        value.contains('logon') ||
        value.contains('authenticate');
  }

  static String siteHome(String loginUrl) {
    final uri = Uri.tryParse(loginUrl);
    if (uri == null || uri.host.isEmpty) return loginUrl;
    return '${uri.scheme}://${uri.host}/';
  }

  static bool _sameStore(String loginUrl, String currentUrl) {
    final home = Uri.tryParse(loginUrl);
    final current = Uri.tryParse(currentUrl);
    if (home == null || current == null) return false;
    if (current.scheme != 'http' && current.scheme != 'https') return false;
    final homeHost = home.host.replaceFirst(RegExp(r'^www\.'), '');
    final currentHost = current.host.replaceFirst(RegExp(r'^www\.'), '');
    if (homeHost.isEmpty || currentHost.isEmpty) return false;
    return currentHost == homeHost || currentHost.endsWith('.$homeHost');
  }

  /// Saves the current page. Login URLs never wipe a good logged-in session.
  static Future<void> saveUrl({
    required String storeId,
    required String homeUrl,
    required String currentUrl,
  }) async {
    if (!_sameStore(homeUrl, currentUrl)) return;
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool(_loggedKey(storeId)) ?? false;
    final isLogin = looksLikeLogin(currentUrl);

    if (isLogin) {
      // Keep the old page if the user was already logged in.
      if (logged) return;
      await prefs.setString(_urlKey(storeId), currentUrl);
      return;
    }

    await prefs.setBool(_loggedKey(storeId), true);
    await prefs.setString(_urlKey(storeId), currentUrl);
  }

  /// Opens the last shop page when logged in — never forces login again.
  static Future<String> openUrl({
    required String storeId,
    required String loginUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool(_loggedKey(storeId)) ?? false;
    final saved = prefs.getString(_urlKey(storeId));
    final home = siteHome(loginUrl);

    if (logged) {
      if (saved != null &&
          saved.isNotEmpty &&
          _sameStore(loginUrl, saved) &&
          !looksLikeLogin(saved)) {
        return saved;
      }
      return home;
    }

    if (saved != null &&
        saved.isNotEmpty &&
        _sameStore(loginUrl, saved) &&
        !looksLikeLogin(saved)) {
      await prefs.setBool(_loggedKey(storeId), true);
      return saved;
    }

    return loginUrl;
  }

  /// All ecommerce session flags/URLs for full backup.
  static Future<List<Map<String, dynamic>>> exportAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys()) {
      if (key.startsWith('ecom_last_url_')) {
        final storeId = key.substring('ecom_last_url_'.length);
        out.add({
          'storeId': storeId,
          'url': prefs.getString(key),
          'logged': prefs.getBool(_loggedKey(storeId)) ?? false,
        });
      } else if (key.startsWith('ecom_logged_')) {
        final storeId = key.substring('ecom_logged_'.length);
        if (out.any((e) => e['storeId'] == storeId)) continue;
        out.add({
          'storeId': storeId,
          'url': prefs.getString(_urlKey(storeId)),
          'logged': prefs.getBool(key) ?? false,
        });
      }
    }
    return out;
  }

  static Future<void> importAll(List<dynamic>? raw) async {
    if (raw == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final e in raw) {
      if (e is! Map) continue;
      final storeId = e['storeId'] as String?;
      if (storeId == null || storeId.isEmpty) continue;
      final url = e['url'] as String?;
      if (url != null && url.isNotEmpty) {
        await prefs.setString(_urlKey(storeId), url);
      }
      if (e.containsKey('logged')) {
        await prefs.setBool(_loggedKey(storeId), e['logged'] == true);
      }
    }
  }
}
