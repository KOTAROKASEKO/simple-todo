import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Frosted "liquid glass" background for [AppBar.flexibleSpace].
///
/// Use with [AppBar.backgroundColor] = transparent and
/// [Scaffold.extendBodyBehindAppBar] = true so content blurs behind the bar.
class LiquidGlassAppBarBackground extends StatelessWidget {
  const LiquidGlassAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.82),
                Colors.white.withValues(alpha: 0.58),
                const Color(0xFFF6F7F9).withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.65),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
