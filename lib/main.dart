import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:simpletodo/app.dart';
import 'package:simpletodo/firebase_options.dart';
import 'package:simpletodo/widget_interactivity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }
  runApp(const TodoApp());
}
