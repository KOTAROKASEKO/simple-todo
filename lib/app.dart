import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simpletodo/app_theme_controller.dart';
import 'package:simpletodo/auth_gate.dart';
import 'package:simpletodo/notification_service.dart';
import 'package:simpletodo/pages/super_important_alarm_page.dart';

/// Matches [ThemeData.scaffoldBackgroundColor] so TextField outlines blend in.
const Color _kLightScaffoldBg = Color(0xFFF6F7F9);

ThemeData _appLightTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'sans-serif',
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'sans-serif'),
    brightness: Brightness.light,
    scaffoldBackgroundColor: _kLightScaffoldBg,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimary: Colors.white,
      secondary: Color(0xFF111111),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF161616),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _kLightScaffoldBg,
      foregroundColor: Color(0xFF111111),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: const Color(0xFFDCE0E8),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE9EBF1)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFFDFDFD),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kLightScaffoldBg),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kLightScaffoldBg),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kLightScaffoldBg, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        minimumSize: const Size(0, 48),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: Color(0xFFBBC2CF), width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF111111);
        }
        return null;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
  );
}

ThemeData _appDarkTheme() {
  const surface = Color(0xFF1A1A1E);
  const scaffold = Color(0xFF121214);
  // Soft light grey for body copy and icons (not near-white).
  const fg = Color(0xFFC8CCD6);
  const fgMuted = Color(0xFF9DA3B0);
  // Slightly brighter than [fg] so primary buttons still read as controls.
  const btnFill = Color(0xFFD6DAE3);
  final darkBase = ThemeData.dark().textTheme;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'sans-serif',
    textTheme: darkBase
        .apply(
          fontFamily: 'sans-serif',
          bodyColor: fg,
          displayColor: fg,
        )
        .copyWith(
          titleLarge:
              darkBase.titleLarge?.copyWith(color: fg, fontFamily: 'sans-serif'),
          titleMedium: darkBase.titleMedium
              ?.copyWith(color: fg, fontFamily: 'sans-serif'),
          titleSmall:
              darkBase.titleSmall?.copyWith(color: fg, fontFamily: 'sans-serif'),
          bodyLarge:
              darkBase.bodyLarge?.copyWith(color: fg, fontFamily: 'sans-serif'),
          bodyMedium: darkBase.bodyMedium
              ?.copyWith(color: fg, fontFamily: 'sans-serif'),
          bodySmall: darkBase.bodySmall
              ?.copyWith(color: fgMuted, fontFamily: 'sans-serif'),
          labelLarge: darkBase.labelLarge
              ?.copyWith(color: fg, fontFamily: 'sans-serif'),
          labelMedium: darkBase.labelMedium
              ?.copyWith(color: fgMuted, fontFamily: 'sans-serif'),
        ),
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme.dark(
      primary: fg,
      onPrimary: scaffold,
      secondary: fg,
      onSecondary: scaffold,
      surface: surface,
      onSurface: fg,
      onSurfaceVariant: fgMuted,
      outline: const Color(0xFF3A3A42),
      outlineVariant: const Color(0xFF323238),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: const Color(0xFF4A4E58),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2E2E34)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF222228),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: scaffold),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: scaffold),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: scaffold, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: btnFill,
        foregroundColor: scaffold,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        minimumSize: const Size(0, 48),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: Color(0xFF5C6370), width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return fg;
        }
        return null;
      }),
      checkColor: WidgetStateProperty.all(scaffold),
    ),
  );
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<SuperImportantAlarmPayload>? _alarmSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppThemeController.instance.loadFromPrefs());
    _alarmSub = NotificationService.instance.superImportantAlarms.listen(
      _openAlarmPage,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.flushDueSuperImportantAlarms();
    }
  }

  void _openAlarmPage(SuperImportantAlarmPayload payload) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => SuperImportantAlarmPage(
          title: payload.title,
          scheduledAtMillis: payload.scheduledAtMillis,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Firebase Todo',
          themeMode: AppThemeController.instance.themeMode,
          theme: _appLightTheme(),
          darkTheme: _appDarkTheme(),
          home: const AuthGate(),
        );
      },
    );
  }
}
