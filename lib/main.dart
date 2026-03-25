import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/app.dart';
import 'package:simpletodo/firebase_options.dart';
import 'package:simpletodo/models/task_model.dart';
import 'package:simpletodo/notification_service.dart';
import 'package:simpletodo/push_notification_service.dart';
import 'package:simpletodo/widget_interactivity.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Hive is not used on web (task list uses Firestore directly there)
  if (!kIsWeb) {
    await Hive.initFlutter();
    Hive.registerAdapter(HiveTaskAdapter());
    Hive.registerAdapter(HiveChecklistItemAdapter());
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
    await NotificationService.instance.init();
    await PushNotificationService.instance.init();
  }
  runApp(const TodoApp());
}
