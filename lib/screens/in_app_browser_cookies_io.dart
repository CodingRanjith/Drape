import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Keep store cookies so Flipkart / Amazon stay logged in next visit.
Future<void> enablePersistentStoreCookies(WebViewController controller) async {
  if (kIsWeb) return;
  try {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      final cookies = WebViewCookieManager();
      final androidCookies = cookies.platform;
      if (androidCookies is AndroidWebViewCookieManager) {
        await androidCookies.setAcceptThirdPartyCookies(platform, true);
      }
    }
  } catch (error, stack) {
    debugPrint('Store cookie setup failed: $error\n$stack');
  }
}
