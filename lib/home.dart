import 'package:flutter/material.dart';
import 'package:tante/features/landlord/landlord_home.dart';
import 'package:tante/features/tenant/tenant_home.dart';
import 'package:tante/services/tante_api.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ModalRoute.of(context)?.settings.arguments;
    if (session is! AuthSession) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to continue.')),
      );
    }
    return session.role == 'Landlord'
        ? LandlordHomePage(session: session)
        : TenantHomePage(session: session);
  }
}
