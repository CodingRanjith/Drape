import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/store_browser_session.dart';
import '../theme/app_theme.dart';
import '../widgets/mine_logo_mark.dart';
import '../widgets/page_background.dart';
import 'in_app_browser_screen.dart';

class EcommerceScreen extends StatelessWidget {
  const EcommerceScreen({super.key});

  static const _stores = <_Store>[
    _Store(
      id: 'amazon',
      name: 'Amazon',
      asset: 'assets/ecommerce/amazon.png',
      loginUrl: 'https://www.amazon.in/ap/signin',
      color: Color(0xFFFF9900),
    ),
    _Store(
      id: 'flipkart',
      name: 'Flipkart',
      asset: 'assets/ecommerce/flipkart.png',
      loginUrl: 'https://www.flipkart.com/account/login',
      color: Color(0xFF2874F0),
    ),
    _Store(
      id: 'myntra',
      name: 'Myntra',
      asset: 'assets/ecommerce/myntra.png',
      loginUrl: 'https://www.myntra.com/login',
      color: Color(0xFFFF3F6C),
    ),
    _Store(
      id: 'ajio',
      name: 'Ajio',
      asset: 'assets/ecommerce/ajio.png',
      loginUrl: 'https://www.ajio.com/login',
      color: Color(0xFF2C2C2C),
    ),
    _Store(
      id: 'meesho',
      name: 'Meesho',
      asset: 'assets/ecommerce/meesho.png',
      loginUrl: 'https://www.meesho.com/auth',
      color: Color(0xFF9F2089),
    ),
    _Store(
      id: 'nykaa',
      name: 'Nykaa',
      asset: 'assets/ecommerce/nykaa.png',
      loginUrl: 'https://www.nykaa.com/auth/login',
      color: Color(0xFFFC2779),
    ),
    _Store(
      id: 'tatacliq',
      name: 'Tata CLiQ',
      asset: 'assets/ecommerce/tatacliq.png',
      loginUrl: 'https://www.tatacliq.com/login',
      color: Color(0xFF0B1D3A),
    ),
    _Store(
      id: 'snapdeal',
      name: 'Snapdeal',
      asset: 'assets/ecommerce/snapdeal.png',
      loginUrl: 'https://www.snapdeal.com/login',
      color: Color(0xFFE40046),
    ),
    _Store(
      id: 'shein',
      name: 'Shein',
      asset: 'assets/ecommerce/shein.png',
      loginUrl: 'https://www.sheinindia.in/user/login',
      color: Color(0xFF000000),
    ),
    _Store(
      id: 'hm',
      name: 'H&M',
      asset: 'assets/ecommerce/hm.png',
      loginUrl: 'https://www2.hm.com/en_in/login',
      color: Color(0xFFE50010),
    ),
    _Store(
      id: 'zara',
      name: 'Zara',
      asset: 'assets/ecommerce/zara.png',
      loginUrl: 'https://www.zara.com/in/en/user/logon',
      color: Color(0xFF1A1A1A),
    ),
    _Store(
      id: 'westside',
      name: 'Westside',
      asset: 'assets/ecommerce/westside.png',
      loginUrl: 'https://www.westside.com/account/login',
      color: Color(0xFFB11226),
    ),
    _Store(
      id: 'lifestyle',
      name: 'Lifestyle',
      asset: 'assets/ecommerce/lifestyle.png',
      loginUrl: 'https://www.lifestylestores.com/in/en/login',
      color: Color(0xFFE31E24),
    ),
    _Store(
      id: 'pantaloons',
      name: 'Pantaloons',
      asset: 'assets/ecommerce/pantaloons.png',
      loginUrl: 'https://www.pantaloons.com/login',
      color: Color(0xFF6B2D5B),
    ),
    _Store(
      id: 'max',
      name: 'Max',
      asset: 'assets/ecommerce/max.png',
      loginUrl: 'https://www.maxfashion.in/in/en/login',
      color: Color(0xFF00A0E3),
    ),
    _Store(
      id: 'shoppersstop',
      name: 'Shoppers',
      asset: 'assets/ecommerce/shoppersstop.png',
      loginUrl: 'https://www.shoppersstop.com/login',
      color: Color(0xFFC41230),
    ),
    _Store(
      id: 'bewakoof',
      name: 'Bewakoof',
      asset: 'assets/ecommerce/bewakoof.png',
      loginUrl: 'https://www.bewakoof.com/login',
      color: Color(0xFFFFD200),
    ),
    _Store(
      id: 'fabindia',
      name: 'Fabindia',
      asset: 'assets/ecommerce/fabindia.png',
      loginUrl: 'https://www.fabindia.com/login',
      color: Color(0xFF7A1F1F),
    ),
    _Store(
      id: 'urbanic',
      name: 'Urbanic',
      asset: 'assets/ecommerce/urbanic.png',
      loginUrl: 'https://in.urbanic.com/login',
      color: Color(0xFF222222),
    ),
    _Store(
      id: 'snitch',
      name: 'Snitch',
      asset: 'assets/ecommerce/snitch.png',
      loginUrl: 'https://www.snitch.co.in/account/login',
      color: Color(0xFF111111),
    ),
  ];

  Future<void> _openLogin(BuildContext context, _Store store) async {
    HapticFeedback.selectionClick();
    final url = await StoreBrowserSession.openUrl(
      storeId: store.id,
      loginUrl: store.loginUrl,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppBrowserScreen(
          storeId: store.id,
          title: store.name,
          url: url,
          homeUrl: store.loginUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: Row(
                  children: [
                    const MineLogoMark(size: 44, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ecommerce',
                            style: GoogleFonts.manrope(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Login once — next visit opens your last page',
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _stores.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final store = _stores[index];
                    return _StoreTile(
                      store: store,
                      onTap: () => _openLogin(context, store),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Store {
  const _Store({
    required this.id,
    required this.name,
    required this.asset,
    required this.loginUrl,
    required this.color,
  });

  final String id;
  final String name;
  final String asset;
  final String loginUrl;
  final Color color;
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.store, required this.onTap});

  final _Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                store.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) {
                  debugPrint('Logo missing ${store.asset}: $error');
                  return _LetterMark(store: store);
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterMark extends StatelessWidget {
  const _LetterMark({required this.store});

  final _Store store;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: store.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          store.name.substring(0, 1).toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: store.color,
          ),
        ),
      ),
    );
  }
}
