import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[PushNotificationService] Foreground message: ${message.messageId}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[PushNotificationService] Opened from notification: ${message.messageId}',
      );
    });

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      await _saveTokenForUser(user.uid);
    });

    await _saveCurrentUserTokenIfAvailable();

    messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _saveTokenForUser(user.uid, tokenOverride: token);
    });

    _initialized = true;
  }

  Future<void> _saveCurrentUserTokenIfAvailable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _saveTokenForUser(user.uid);
  }

  Future<void> _saveTokenForUser(
    String uid, {
    String? tokenOverride,
  }) async {
    final token = tokenOverride ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final tokenRef = FirebaseFirestore.instance
        .collection('todo')
        .doc(uid)
        .collection('deviceTokens')
        .doc(token);

    await tokenRef.set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.name,
    }, SetOptions(merge: true));
  }
}
