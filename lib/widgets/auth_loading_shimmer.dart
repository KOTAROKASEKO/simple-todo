import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shown while [FirebaseAuth.authStateChanges] has not emitted the first event
/// (matches [LoginPage] layout so the transition feels smooth).
class AuthLoadingShimmer extends StatelessWidget {
  const AuthLoadingShimmer({super.key});

  static const Color _base = Color(0xFFD8DCE3);
  static const Color _highlight = Color(0xFFF0F2F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Shimmer.fromColors(
                  baseColor: _base,
                  highlightColor: _highlight,
                  period: const Duration(milliseconds: 1200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 26,
                        width: 140,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
