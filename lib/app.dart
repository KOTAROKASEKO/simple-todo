import 'package:flutter/material.dart';
import 'package:simpletodo/auth_gate.dart';

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Todo',
      theme: ThemeData(
        useMaterial3: true,
        // Use system font so no network font fetch (avoids CORS/fetch errors on web)
        fontFamily: 'sans-serif',
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'sans-serif'),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF111111),
          onPrimary: Colors.white,
          secondary: Color(0xFF111111),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF161616),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7F9),
          foregroundColor: Color(0xFF111111),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        dividerColor: Color(0xFFE4E6EB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EBF1)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFDFDFD),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE1E4EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE1E4EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF111111), width: 1.3),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            minimumSize: const Size(0, 48),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
