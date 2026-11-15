import 'package:flutter/material.dart';

import 'package:tante/home.dart';
import 'package:tante/landing_page.dart';
import 'package:tante/login.dart';
import 'package:tante/features/listing/listings_page.dart';
import 'package:tante/features/listing/unit_details_page.dart';
import 'package:tante/features/auth/create_account_page.dart';
import 'package:tante/features/auth/complete_user_profile_page.dart';
import 'package:tante/services/tante_api.dart';
import 'package:tante/tante_colors.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.api});

  final TanteApi? api;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DFED)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DFED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: TanteColors.green, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x19193760),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const LandingPage(),
            );
          case '/home':
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => HomePage(api: api),
            );
          case '/login':
            final arguments = settings.arguments;
            final loginArgs = arguments is LoginRouteArgs
                ? arguments
                : LoginRouteArgs(
                    role: arguments == 'Tenant' ? 'Tenant' : 'Landlord',
                  );
            return MaterialPageRoute<AuthSession>(
              settings: settings,
              builder: (_) => Login(
                initialRole: loginArgs.role,
                returnToPreviousRoute: loginArgs.returnToPreviousRoute,
                api: api,
              ),
            );
          case '/register':
            final arguments = settings.arguments;
            final registerArgs = arguments is CreateAccountRouteArgs
                ? arguments
                : const CreateAccountRouteArgs();
            return MaterialPageRoute<String>(
              settings: settings,
              builder: (_) => CreateAccountPage(
                api: api ?? TanteApi(),
                initialPhoneNumber: registerArgs.initialPhoneNumber,
              ),
            );
          case '/complete-user-profile':
            final arguments = settings.arguments;
            if (arguments is! CompleteUserProfileRouteArgs) return null;
            return MaterialPageRoute<AuthSession>(
              settings: settings,
              builder: (_) => CompleteUserProfilePage(
                api: api ?? TanteApi(),
                phoneNumber: arguments.phoneNumber,
                token: arguments.token,
                role: arguments.role,
              ),
            );
          case '/listings':
            final arguments = settings.arguments;
            final filters = arguments is Map
                ? arguments.map(
                    (key, value) => MapEntry(key.toString(), value.toString()),
                  )
                : const <String, String>{};
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ListingsPage(initialFilters: filters, api: api),
            );
          case '/unit-details':
            final unitId = settings.arguments;
            if (unitId is! int || unitId <= 0) return null;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => UnitDetailsPage(unitId: unitId, api: api),
            );
        }
        return null;
      },
    );
  }
}
