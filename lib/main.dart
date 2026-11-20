import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alarm/alarm.dart';

import 'data/store.dart';
import 'screens/dose_ring_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/dose_alarm_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

bool _errorShown = false;

/// Root navigator, used to push the full-screen ring screen when a dose
/// alarm fires — including when the alarm relaunched the app from killed.
final navigatorKey = GlobalKey<NavigatorState>();

bool _ringShowing = false;

/// When a dose alarm starts ringing, show the alarm-clock screen for it.
void _listenForRings() {
  Alarm.ringStream.stream.listen((alarm) async {
    final info = DoseAlarmService.instance.lookup(alarm.id);
    if (info == null || _ringShowing) return;
    // Wait until the navigator exists (alarm may relaunch the app).
    for (var i = 0; i < 50 && navigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    final nav = navigatorKey.currentState;
    if (nav == null || _ringShowing) return;
    _ringShowing = true;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => DoseRingScreen(
          alarmId: alarm.id,
          medId: info['medId'] ?? '',
          medName: info['medName'] ?? alarm.notificationSettings.title,
          scheduledFor:
              DateTime.tryParse(info['scheduledFor'] ?? '') ?? alarm.dateTime,
          body: info['body'] ?? alarm.notificationSettings.body,
        ),
      ),
    );
    _ringShowing = false;
  });
}

/// Crash catcher: route framework + platform errors to a friendly error
/// screen. The replacement runApp is DEFERRED — calling runApp synchronously
/// inside an error handler throws "lockState called during build" and kills
/// the isolate with no screen at all.
void _showError(Object error) {
  if (_errorShown) return;
  _errorShown = true;
  Future.delayed(Duration.zero, () {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.health_and_safety_rounded,
                    size: 56,
                    color: AppTheme.seed,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dosique hit an unexpected error. Your medicines and history '
                    'are stored on this phone and are not lost. Please close and '
                    'reopen the app.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '$error',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _showError(details.exception);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _showError(error);
    return true;
  };

  final store = AppStore();
  await NotificationService.instance.init();
  await DoseAlarmService.instance.init();
  _listenForRings();
  await store.load();

  runApp(ChangeNotifierProvider.value(value: store, child: const DosiqueApp()));
}

class DosiqueApp extends StatelessWidget {
  const DosiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final themeMode = switch (s.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'Dosique',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(senior: s.seniorMode),
      darkTheme: AppTheme.dark(senior: s.seniorMode),
      themeMode: themeMode,
      home: !store.loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : s.onboardingDone
          ? const HomeShell()
          : const OnboardingScreen(),
    );
  }
}
