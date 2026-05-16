import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpletodo/pages/intro_onboarding_page.dart';
import 'package:simpletodo/pages/todo_home_page.dart';
import 'package:simpletodo/widgets/auth_loading_shimmer.dart';

/// Resolves the signed-in user from [authStateChanges] and
/// [FirebaseAuth.instance.currentUser] (local persistence).
///
/// Some platforms leave [authStateChanges] in [ConnectionState.waiting]
/// when offline; without a cap the app would show [AuthLoadingShimmer] forever.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  /// Call this immediately before [FirebaseAuth.instance.signOut()] so that
  /// [AuthGate] skips the null-grace window and shows the login screen right
  /// away instead of keeping the stale user on screen for up to 3 s.
  static void markIntentionalSignOut() {
    _intentionalSignOut = true;
  }

  // Package-private – reset by _AuthGateState after it has reacted.
  static bool _intentionalSignOut = false;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const Duration _kAuthWaitCap = Duration(seconds: 2);
  static const Duration _kNullGrace = Duration(seconds: 3);

  Timer? _waitCapTimer;
  Timer? _nullGraceTimer;
  bool _waitCapElapsed = false;
  User? _lastKnownUser;
  DateTime? _nullSeenAt;

  @override
  void initState() {
    super.initState();
    _waitCapTimer = Timer(_kAuthWaitCap, () {
      if (!mounted) return;
      setState(() => _waitCapElapsed = true);
    });
  }

  @override
  void dispose() {
    _waitCapTimer?.cancel();
    _nullGraceTimer?.cancel();
    super.dispose();
  }

  User? _resolvedUser(AsyncSnapshot<User?> snapshot) {
    return snapshot.data ?? FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Auth error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final user = _resolvedUser(snapshot);
        if (user != null) {
          _waitCapTimer?.cancel();
          _waitCapTimer = null;
          _nullGraceTimer?.cancel();
          _nullGraceTimer = null;
          _nullSeenAt = null;
          _lastKnownUser = user;
          return TodoHomePage(user: user);
        }

        // Some devices briefly emit null despite persisted auth. Keep the
        // last known user for a short grace window to avoid false logout UI.
        final sticky = _lastKnownUser;
        if (sticky != null) {
          // Skip grace window entirely when the user explicitly signed out.
          if (AuthGate._intentionalSignOut) {
            AuthGate._intentionalSignOut = false;
            _nullGraceTimer?.cancel();
            _nullGraceTimer = null;
            _lastKnownUser = null;
            _nullSeenAt = null;
          } else {
            final now = DateTime.now();
            final seenAt = _nullSeenAt;
            if (seenAt == null) {
              _nullSeenAt = now;
              _nullGraceTimer?.cancel();
              _nullGraceTimer = Timer(_kNullGrace, () {
                if (!mounted) return;
                setState(() {
                  _lastKnownUser = null;
                  _nullSeenAt = null;
                });
              });
              return TodoHomePage(user: sticky);
            }
            if (now.difference(seenAt) < _kNullGrace) {
              return TodoHomePage(user: sticky);
            }
            _lastKnownUser = null;
            _nullSeenAt = null;
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !_waitCapElapsed) {
          return const AuthLoadingShimmer();
        }

        // Past wait cap or stream active: still merge [currentUser] once more.
        final again = _resolvedUser(snapshot);
        if (again != null) {
          _waitCapTimer?.cancel();
          _waitCapTimer = null;
          return TodoHomePage(user: again);
        }

        return const IntroOnboardingPage();
      },
    );
  }
}
