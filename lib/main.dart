import 'package:flutter/material.dart';
import 'package:tante/home.dart';
import 'package:tante/loadingPage.dart';
import 'package:tante/login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tante',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme(
          brightness: Brightness.light,

          // Primary = Deep Navy
          primary: const Color(0xFF0F172A),
          onPrimary: Colors.white,

          // Secondary = Teal
          secondary: const Color(0xFF0F766E),
          onSecondary: Colors.white,

          // Surface / cards
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),

          // Error
          error: Colors.red,
          onError: Colors.white,

          // Background style
          tertiary: const Color(0xFFD4A017), // Gold Accent
          onTertiary: Colors.white,
        ),

        scaffoldBackgroundColor: const Color(0xFFF8FAFC),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          centerTitle: true,
          elevation: 0,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      routes: {
        '/': (context) => LoadingPage(),
        '/home': (context) => HomePage(),
        '/login': (context) => Login()
      },
    );
  }
}
  
