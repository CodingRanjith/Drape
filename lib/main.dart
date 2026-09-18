import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_nav.dart';
import 'screens/alarm_ring_screen.dart';
import 'screens/logo_prepage_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_walkthrough_screen.dart';
import 'services/notify.dart';
import 'state/mine_state.dart';
import 'theme/app_theme.dart';
import 'product.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MineRoot());
}

class MineRoot extends StatefulWidget {
  const MineRoot({super.key});

  @override
  State<MineRoot> createState() => _MineRootState();
}

class _MineRootState extends State<MineRoot> with WidgetsBindingObserver {
  late final MineState _state;
  String? _alarmRouteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = MineState();
    _state.onShowAlarm = _openAlarm;
    unawaited(
      _state.boot().then((_) => initEventAlarms(onAlarm: _state.handleAlarm)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.onShowAlarm = null;
    _state.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_state.checkDueAlarms());
    }
  }

  void _openAlarm(String eventId) {
    if (!mounted || eventId.isEmpty) return;
    if (_alarmRouteId == eventId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      _alarmRouteId = eventId;
      nav
          .push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => AlarmRingScreen(eventId: eventId),
            ),
          )
          .whenComplete(() => _alarmRouteId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp(
        title: MineProduct.appName,
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  var _minElapsed = false;
  Timer? _logoTimer;

  @override
  void initState() {
    super.initState();
    // Keep logo on screen long enough for intro motion + chime to finish.
    _logoTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  @override
  void dispose() {
    _logoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final showLogo = state.loading || !_minElapsed;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showLogo
          ? const LogoPrepageScreen(key: ValueKey('logo'))
          : KeyedSubtree(
              key: const ValueKey('app'),
              child: _HomeFor(state: state),
            ),
    );
  }
}

class _HomeFor extends StatelessWidget {
  const _HomeFor({required this.state});

  final MineState state;

  @override
  Widget build(BuildContext context) {
    if (!state.profile.walkthroughSeen) {
      return SplashWalkthroughScreen(
        onFinished: () => unawaited(state.completeWalkthrough()),
      );
    }
    if (!state.profile.onboarded) {
      return const OnboardingScreen();
    }
    return const ShellScreen();
  }
}
