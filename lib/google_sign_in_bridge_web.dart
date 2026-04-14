import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;
import 'package:simpletodo/services/google_sign_in_firebase.dart';

Widget buildGoogleSignInWebAuthButton({
  required VoidCallback onFirebaseSignInStarted,
  required VoidCallback onFirebaseSignInFinished,
  required void Function(String message) onFirebaseSignInFailed,
}) {
  return _GoogleSignInWebAuthButton(
    onFirebaseSignInStarted: onFirebaseSignInStarted,
    onFirebaseSignInFinished: onFirebaseSignInFinished,
    onFirebaseSignInFailed: onFirebaseSignInFailed,
  );
}

class _GoogleSignInWebAuthButton extends StatefulWidget {
  const _GoogleSignInWebAuthButton({
    required this.onFirebaseSignInStarted,
    required this.onFirebaseSignInFinished,
    required this.onFirebaseSignInFailed,
  });

  final VoidCallback onFirebaseSignInStarted;
  final VoidCallback onFirebaseSignInFinished;
  final void Function(String message) onFirebaseSignInFailed;

  @override
  State<_GoogleSignInWebAuthButton> createState() =>
      _GoogleSignInWebAuthButtonState();
}

class _GoogleSignInWebAuthButtonState extends State<_GoogleSignInWebAuthButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _sub = GoogleSignIn.instance.authenticationEvents.listen(
      _onAuthEvent,
      onError: _onAuthError,
    );
  }

  Future<void> _onAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (!mounted || event is! GoogleSignInAuthenticationEventSignIn) return;
    if (_linking) return;
    _linking = true;
    widget.onFirebaseSignInStarted();
    try {
      await firebaseSignInWithGoogleAccount(event.user);
      if (mounted) widget.onFirebaseSignInFinished();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        widget.onFirebaseSignInFailed(
          e.message ?? 'Google sign-in failed.',
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onFirebaseSignInFailed(
          e is StateError ? e.message : '$e',
        );
      }
    } finally {
      _linking = false;
    }
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    if (error is GoogleSignInException) {
      final msg = userVisibleMessageForGoogleSignInException(error);
      if (msg != null) {
        widget.onFirebaseSignInFailed(msg);
      } else {
        widget.onFirebaseSignInFinished();
      }
    } else {
      widget.onFirebaseSignInFailed('$error');
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: gsi_web.renderButton(),
    );
  }
}
