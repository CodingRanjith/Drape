import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/store_browser_session.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import 'in_app_browser_cookies_stub.dart'
    if (dart.library.io) 'in_app_browser_cookies_io.dart';

/// Opens a store website inside Mine — no separate browser window.
class InAppBrowserScreen extends StatefulWidget {
  const InAppBrowserScreen({
    super.key,
    required this.storeId,
    required this.title,
    required this.url,
    required this.homeUrl,
  });

  final String storeId;
  final String title;
  final String url;
  final String homeUrl;

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _progress = 0;
  var _canGoBack = false;
  var _pageHost = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageHost = Uri.tryParse(widget.url)?.host ?? '';
    _boot();
  }

  Future<void> _boot() async {
    late final WebViewController controller;
    controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
              _pageHost = Uri.tryParse(url)?.host ?? _pageHost;
            });
          },
          onPageFinished: (url) async {
            await _remember(url);
            if (!mounted) return;
            final back = await controller.canGoBack();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _canGoBack = back;
              _pageHost = Uri.tryParse(url)?.host ?? _pageHost;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _error = 'Could not load this page inside Mine.';
              });
            }
          },
        ),
      );

    await enablePersistentStoreCookies(controller);
    await controller.loadRequest(Uri.parse(widget.url));
    if (!mounted) return;
    setState(() => _controller = controller);
  }

  Future<void> _remember([String? url]) async {
    final controller = _controller;
    final current = url ?? await controller?.currentUrl();
    if (current == null || current.isEmpty) return;
    await StoreBrowserSession.saveUrl(
      storeId: widget.storeId,
      homeUrl: widget.homeUrl,
      currentUrl: current,
    );
  }

  void _closeToEcommerce() {
    _remember();
    Navigator.of(context).pop();
  }

  Future<void> _pageBack() async {
    final controller = _controller;
    if (controller == null) return;
    if (await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _remember();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.ink,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Ecommerce',
            onPressed: _closeToEcommerce,
            icon: const BackArrowGlyph(size: 20),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              Text(
                _pageHost.isEmpty
                    ? (Uri.tryParse(widget.url)?.host ?? widget.url)
                    : _pageHost,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          actions: [
            if (_canGoBack)
              IconButton(
                tooltip: 'Previous page',
                onPressed: _pageBack,
                icon: const Icon(Icons.undo_rounded, size: 20),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller == null
                  ? null
                  : () {
                      setState(() {
                        _error = null;
                        _loading = true;
                      });
                      controller.reload();
                    },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_loading)
              LinearProgressIndicator(
                value: _progress > 0 && _progress < 100 ? _progress / 100 : null,
                minHeight: 2,
                color: AppColors.terracotta,
                backgroundColor: AppColors.terracottaSoft,
              ),
            Expanded(
              child: _error != null
                  ? _BrowserError(
                      message: _error!,
                      onRetry: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                        });
                        controller?.loadRequest(Uri.parse(widget.url));
                      },
                    )
                  : controller == null
                      ? const Center(child: CircularProgressIndicator())
                      : WebViewWidget(controller: controller),
            ),
            if (kIsWeb)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Text(
                    'Login stays on the phone app. Chrome web may ask again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowserError extends StatelessWidget {
  const _BrowserError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.public_off_rounded,
              size: 42,
              color: AppColors.clay,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
