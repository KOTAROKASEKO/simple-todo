import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:simpletodo/firebase_options.dart';

/// Web OAuth client ID from Firebase Console (Project settings → Your apps).
/// Use `--dart-define=GOOGLE_WEB_CLIENT_ID=...` when building.
/// Android needs this as [serverClientId] so the plugin returns an ID token.
const String kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

bool _googleSignInInitializeSucceeded = false;

/// OAuth 2.0 Web client ID for `initialize` (browser) / `serverClientId` (mobile).
///
/// [String.fromEnvironment] overrides all. On **web**, we always fall back to
/// [DefaultFirebaseOptions.googleServerClientId] so Sign-In works even when
/// `defaultTargetPlatform` is not `android`/`iOS`/`macOS` (e.g. some Wasm builds).
String _resolvedGoogleWebClientId() {
  final fromEnv = kGoogleWebClientId.trim();
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) {
    return DefaultFirebaseOptions.googleServerClientId;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return DefaultFirebaseOptions.googleServerClientId;
    default:
      return '';
  }
}

Future<void> initializeGoogleSignInForApp() async {
  final id = _resolvedGoogleWebClientId();
  if (kIsWeb && id.isEmpty) {
    debugPrint(
      'Google Sign-In (web): missing OAuth client ID. Use '
      '--dart-define=GOOGLE_WEB_CLIENT_ID=... or web/index.html '
      'meta google-signin-client_id.',
    );
  }
  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb && id.isNotEmpty ? id : null,
    serverClientId: !kIsWeb && id.isNotEmpty ? id : null,
  );
  _googleSignInInitializeSucceeded = true;
}

Future<void> firebaseSignInWithGoogleAccount(GoogleSignInAccount account) async {
  final idToken = account.authentication.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw StateError(
      'Google did not return an ID token. Add your Web client ID from '
      'Firebase (Project settings) as GOOGLE_WEB_CLIENT_ID when building, '
      'or set the google-signin-client_id meta tag in web/index.html.',
    );
  }
  await FirebaseAuth.instance.signInWithCredential(
    GoogleAuthProvider.credential(idToken: idToken),
  );
}

Future<void> signInWithGoogleUsingAuthenticate() async {
  final account = await GoogleSignIn.instance.authenticate();
  await firebaseSignInWithGoogleAccount(account);
}

String? userVisibleMessageForGoogleSignInException(GoogleSignInException e) {
  return switch (e.code) {
    GoogleSignInExceptionCode.canceled ||
    GoogleSignInExceptionCode.interrupted ||
    GoogleSignInExceptionCode.uiUnavailable =>
      null,
    _ => e.description ?? 'Google sign-in failed.',
  };
}

Future<void> signOutGoogleSilently() async {
  if (!_googleSignInInitializeSucceeded) return;
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}
