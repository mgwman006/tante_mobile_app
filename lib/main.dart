import 'package:flutter/material.dart';

class TanteColors {
  static const navy = Color(0xFF0C2E47);
  static const text = Color(0xFF102F4C);
  static const green = Color(0xFF19A75C);
  static const lime = Color(0xFF80E77D);
  static const gold = Color(0xFFFFC43D);
  static const background = Color(0xFFF3F6FD);
  static const mutedText = Color(0xFF3E5674);
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tante',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TanteColors.green,
          primary: TanteColors.green,
          secondary: TanteColors.gold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: TanteColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: TanteColors.navy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: TanteColors.lime.withValues(alpha: .35),
          backgroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: TanteColors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD7DFED))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD7DFED))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: TanteColors.green, width: 1.5)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x19193760),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Login(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const Login(),
      },
    );
  }
}

import 'package:tante/home.dart';
import 'package:tante/login.dart';
