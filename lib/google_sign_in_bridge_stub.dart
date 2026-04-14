import 'package:flutter/material.dart';

/// Web-only; stub returns nothing.
Widget buildGoogleSignInWebAuthButton({
  required VoidCallback onFirebaseSignInStarted,
  required VoidCallback onFirebaseSignInFinished,
  required void Function(String message) onFirebaseSignInFailed,
}) {
  return const SizedBox.shrink();
}
