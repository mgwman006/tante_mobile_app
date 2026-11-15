import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tante/main.dart';
import 'package:tante/services/tante_api.dart';

void main() {
  test(
    'listed-units API includes selected filters and parses the result',
    () async {
      late Uri requestUri;
      final api = TanteApi(
        client: MockClient((request) async {
          requestUri = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 42,
                    'unitNumber': 'A2',
                    'numberOfBedrooms': 2,
                    'numberOfBathrooms': 1,
                    'rentAmount': 850000,
                    'type': 'FLAT',
                    'status': 'AVAILABLE',
                    'propertyName': 'Green Court',
                    'location': {
                      'address': {
                        'streetName': 'Mlimani Road',
                        'city': 'Dar es Salaam',
                        'region': 'Dar es Salaam',
                      },
                    },
                  },
                ],
                'totalElements': 1,
              },
            }),
            200,
          );
        }),
      );

      final page = await api.getListedUnits(
        page: 0,
        city: 'Dar es Salaam',
        type: 'FLAT',
        minBedrooms: 2,
        minRent: '500000',
        maxRent: '1000000',
      );

      expect(requestUri.scheme, 'http');
      expect(requestUri.host, 'localhost');
      expect(requestUri.port, 8082);
      expect(requestUri.path, '/property-manager/v1/units');
      expect(requestUri.queryParameters['city'], 'Dar es Salaam');
      expect(requestUri.queryParameters['type'], 'FLAT');
      expect(requestUri.queryParameters['minBedrooms'], '2');
      expect(requestUri.queryParameters['minRent'], '500000');
      expect(requestUri.queryParameters['maxRent'], '1000000');
      expect(requestUri.queryParameters['isListed'], 'true');
      expect(page.totalElements, 1);
      expect(page.items.single.propertyName, 'Green Court');
      expect(page.items.single.rentAmount, 850000);
    },
  );

  testWidgets(
    'landing page offers property search and renter/landlord sign-in',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(
        find.text('Find your next place.\nBuild better rental\nrelationships.'),
        findsOneWidget,
      );
      expect(find.text('Find a property'), findsOneWidget);
      expect(find.text("I'm a tenant"), findsOneWidget);
      expect(find.text("I'm a landlord / agent"), findsOneWidget);
    },
  );

  testWidgets('landing page scrolls to the content below the hero', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final list = find.byKey(const ValueKey('landing-page-scroll'));

    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Quick search')).dy, lessThan(100));
  });

  testWidgets('tenant sign-in opens the tenant login form', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text("I'm a tenant"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tante'), findsOneWidget);
    expect(find.text('Log in as Tenant'), findsOneWidget);
  });

  testWidgets('landlord and agent sign-in opens the landlord login form', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm a landlord / agent"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tante'), findsOneWidget);
    expect(find.text('Log in as Landlord'), findsOneWidget);
  });

  testWidgets('property search opens the rental listings screen', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(api: _FakeTanteApi()));

    await tester.ensureVisible(find.text('Search homes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search homes'));
    await tester.pumpAndSettle();

    expect(find.text('Homes for rent'), findsOneWidget);
    expect(find.text('1 place to explore'), findsOneWidget);
  });
}

class _FakeTanteApi extends TanteApi {
  _FakeTanteApi()
    : super(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'success': true, 'data': {}}), 200),
        ),
      );

  @override
  Future<RentalListingsPage> getListedUnits({
    required int page,
    required String city,
    required String type,
    required int minBedrooms,
    required String minRent,
    required String maxRent,
  }) async {
    return const RentalListingsPage(items: [], totalElements: 1);
  }
}
