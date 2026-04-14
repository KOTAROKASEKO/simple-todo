import 'package:flutter/material.dart';
import 'package:simpletodo/widgets/email_password_auth_card.dart';

/// Standalone login (same form as the last slide of [IntroOnboardingPage]).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.onBackToIntro});

  final VoidCallback? onBackToIntro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: onBackToIntro != null
          ? AppBar(
              backgroundColor: const Color(0xFFF6F7F9),
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackToIntro,
                tooltip: 'Back',
              ),
            )
          : null,
      body: SafeArea(
        top: onBackToIntro == null,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const EmailPasswordAuthCard(),
            ),
          ),
        ),
      ),
    );
  }
}
