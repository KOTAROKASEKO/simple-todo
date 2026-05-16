import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/app.dart';
import 'package:simpletodo/firebase_options.dart';
import 'package:simpletodo/notification_service.dart';
import 'package:simpletodo/push_notification_service.dart';
import 'package:simpletodo/services/google_sign_in_firebase.dart';
import 'package:simpletodo/widget_interactivity.dart';

/// Same as [TodoApp] scaffold — avoids a black flash before the first frame.
const Color _kStartupBackground = Color(0xFFF6F7F9);

/// First [runApp] paints immediately; Firebase / Hive finish here so startup
/// does not block the engine from showing a frame.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _initialized = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!kIsWeb) {
        try {
          await initializeGoogleSignInForApp();
        } catch (e, st) {
          debugPrint('Google Sign-In init failed (sign-in may be unavailable): $e');
          debugPrint('$st');
        }
      }
      if (!kIsWeb) {
        await Hive.initFlutter();
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        unawaited(_initAndroidDeferred());
      }
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _initAndroidDeferred() async {
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
    await NotificationService.instance.init();
    await PushNotificationService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: _kStartupBackground,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Could not start the app.\n$_error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: _kStartupBackground,
          child: SizedBox.expand(),
        ),
      );
    }
    return const TodoApp();
  }
}
