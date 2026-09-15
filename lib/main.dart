import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_nav.dart';
import 'screens/alarm_ring_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/notify.dart';
import 'state/drape_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DrapeRoot());
}

class DrapeRoot extends StatefulWidget {
  const DrapeRoot({super.key});

  @override
  State<DrapeRoot> createState() => _DrapeRootState();
}

class _DrapeRootState extends State<DrapeRoot> with WidgetsBindingObserver {
  late final DrapeState _state;
  String? _alarmRouteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = DrapeState();
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
        title: 'Drape',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.profile.onboarded) {
      return const OnboardingScreen();
    }
    return const ShellScreen();
  }
}
