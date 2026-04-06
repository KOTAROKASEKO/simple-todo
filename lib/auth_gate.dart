import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpletodo/pages/login_page.dart';
import 'package:simpletodo/pages/todo_home_page.dart';
import 'package:simpletodo/widgets/auth_loading_shimmer.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7F9),
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

        final user = snapshot.data;
        if (user != null) {
          return TodoHomePage(user: user);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoadingShimmer();
        }

        return const LoginPage();
      },
    );
  }
}
