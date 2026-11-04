import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tante/main.dart';

void main() {
  testWidgets('login offers landlord and tenant account types', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to Tante'), findsOneWidget);
    expect(find.text('Landlord'), findsOneWidget);
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.text('Log in as Landlord'), findsOneWidget);
  });

  testWidgets('tenant login opens tenant overview and rent flow', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byLabelText('Email address'), 'jordan@example.com');
    await tester.enterText(find.byLabelText('Password'), 'password');
    await tester.tap(find.text('Log in as Tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome home, Jordan'), findsOneWidget);
    expect(find.text('Next rent payment'), findsOneWidget);
    expect(find.text('My rent'), findsOneWidget);
  });

  testWidgets('landlord can open properties and create a lease', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byLabelText('Email address'), 'alex@example.com');
    await tester.enterText(find.byLabelText('Password'), 'password');
    await tester.tap(find.text('Log in as Landlord'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Alex'), findsOneWidget);
    await tester.tap(find.text('Leases').last);
    await tester.pumpAndSettle();
    expect(find.text('Create lease'), findsWidgets);
  });
}
