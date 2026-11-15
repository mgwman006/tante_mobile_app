import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tante/features/landlord/pages/create_property_page.dart';
import 'package:tante/features/landlord/pages/landlord_properties_page.dart';
import 'package:tante/features/tenant/tenant_home.dart';
import 'package:tante/main.dart';
import 'package:tante/services/tante_api.dart';

void main() {
  testWidgets('landlord properties displays structured property addresses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LandlordPropertiesPage(
          onAddProperty: () {},
          properties: [
            {
              'name': 'Green Court',
              'type': 'RESIDENTIAL_PROPERTY',
              'location': {
                'address': {
                  'houseNumber': 14,
                  'streetName': 'Mlimani Road',
                  'ward': 'Mlimani',
                  'city': 'Dar es Salaam',
                  'region': 'Dar es Salaam',
                  'country': 'Tanzania',
                },
              },
              'buildings': [],
            },
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Residential Property'), findsOneWidget);
    expect(
      find.text(
        '14, Mlimani Road, Mlimani, Dar es Salaam, Dar es Salaam, Tanzania',
      ),
      findsOneWidget,
    );
  });

  testWidgets('landlord properties page offers an add-property action', (
    tester,
  ) async {
    var addTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LandlordPropertiesPage(
          properties: const [],
          onAddProperty: () => addTapped = true,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();

    expect(addTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'create property API sends the backend contract with authentication',
    () async {
      late http.Request request;
      final api = TanteApi(
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 5, 'name': 'Green Court', 'type': 'COMPOUND'},
            }),
            201,
          );
        }),
      );

      final property = await api.createProperty(
        rentalProfileId: 7,
        createdByUserId: 42,
        token: 'test-token',
        name: ' Green Court ',
        type: 'COMPOUND',
        numberOfBuildings: 2,
        address: {
          'streetName': 'Mlimani Road',
          'city': 'Dar es Salaam',
          'region': 'Dar es Salaam',
          'country': 'Tanzania',
        },
        locationName: 'Dar es Salaam',
        description: 'Rental compound',
        developmentStatus: 'OPERATIONAL',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/property-manager/v1/properties/rental-profile/7',
      );
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(body, {
        'createdByUserId': 42,
        'name': 'Green Court',
        'type': 'COMPOUND',
        'numberOfBuildings': 2,
        'location': {
          'name': 'Dar es Salaam',
          'latitude': 0,
          'longitude': 0,
          'address': {
            'streetName': 'Mlimani Road',
            'city': 'Dar es Salaam',
            'region': 'Dar es Salaam',
            'country': 'Tanzania',
          },
        },
        'description': 'Rental compound',
        'developmentStatus': 'OPERATIONAL',
      });
      expect(property['id'], 5);
    },
  );

  testWidgets('create property page submits a validated property', (
    tester,
  ) async {
    late http.Request request;
    final api = TanteApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 5,
              'name': 'Green Court',
              'type': 'STAND_ALONE_HOUSE',
            },
          }),
          201,
        );
      }),
    );
    const session = AuthSession(
      phoneNumber: '+255712345678',
      token: 'test-token',
      userId: 42,
      role: 'Landlord',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Map<String, dynamic>>(
                  builder: (_) => CreatePropertyPage(
                    api: api,
                    session: session,
                    rentalProfileId: 7,
                  ),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();

    await _enterPropertyText(tester, 'property-name-field', 'Green Court');
    await _enterPropertyText(tester, 'property-street-field', 'Mlimani Road');
    await _enterPropertyText(tester, 'property-city-field', 'Dar es Salaam');
    await _enterPropertyText(tester, 'property-region-field', 'Dar es Salaam');
    await _enterPropertyText(tester, 'property-country-field', 'Tanzania');
    await tester.ensureVisible(find.text('Create property'));
    await tester.tap(find.text('Create property'));
    await tester.pumpAndSettle();

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['createdByUserId'], 42);
    expect(body['name'], 'Green Court');
    expect(body['type'], 'STAND_ALONE_HOUSE');
    expect((body['location'] as Map)['address'], {
      'streetName': 'Mlimani Road',
      'city': 'Dar es Salaam',
      'region': 'Dar es Salaam',
      'country': 'Tanzania',
    });
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('create property page can be cancelled while scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Map<String, dynamic>>(
                  builder: (_) => CreatePropertyPage(
                    api: TanteApi(),
                    session: const AuthSession(
                      phoneNumber: '+255712345678',
                      token: 'test-token',
                      userId: 42,
                      role: 'Landlord',
                    ),
                    rentalProfileId: 7,
                  ),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    final countryField = find.byKey(const ValueKey('property-country-field'));
    for (
      var attempt = 0;
      attempt < 8 && countryField.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
    }
    expect(countryField, findsOneWidget);
    await tester.ensureVisible(countryField);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open form'), findsOneWidget);
  });

  test('tenant details API parses the backend object response', () async {
    late Uri requestUri;
    late String authorization;
    final api = TanteApi(
      client: MockClient((request) async {
        requestUri = request.url;
        authorization = request.headers['Authorization'] ?? '';
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 12,
              'userId': 42,
              'firstName': 'Jordan',
              'lastName': 'Smith',
              'email': 'jordan@example.com',
              'phoneNumber': '+255712345678',
            },
          }),
          200,
        );
      }),
    );

    final tenant = await api.getTenantDetails(42, 'test-token');

    expect(requestUri.path, '/rent-manager/v1/tenants');
    expect(requestUri.queryParameters['userId'], '42');
    expect(authorization, startsWith('Bearer '));
    expect(tenant['id'], 12);
    expect(tenant['firstName'], 'Jordan');
  });

  test('rental profile API loads listing agency details', () async {
    late Uri requestUri;
    late String authorization;
    final api = TanteApi(
      client: MockClient((request) async {
        requestUri = request.url;
        authorization = request.headers['Authorization'] ?? '';
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 7,
              'name': 'Tante Rentals',
              'phoneNumber': '+255712345678',
              'email': 'rentals@example.com',
              'viewingServiceFee': 15000,
              'type': 'BUSINESS',
            },
          }),
          200,
        );
      }),
    );

    final profile = await api.getRentalProfileDetails(7, 'test-token');

    expect(requestUri.path, '/rent-manager/v1/rentalprofiles/7');
    expect(authorization, startsWith('Bearer '));
    expect(profile['name'], 'Tante Rentals');
  });

  test('viewing booking API posts the authenticated booking payload', () async {
    late http.Request request;
    final api = TanteApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 8, 'reference': 'VB-test', 'status': 'PENDING'},
          }),
          201,
        );
      }),
    );
    final startTime = DateTime(2030, 2, 3, 14, 30);

    final booking = await api.createViewingBooking(
      rentalProfileId: 7,
      unitId: 42,
      startTime: startTime,
      requesterUserAccountId: 12,
      serviceFee: 15000,
      token: 'test-token',
      notes: 'Please call on arrival.',
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;

    expect(request.method, 'POST');
    expect(request.url.path, '/rent-manager/v1/viewings/bookings');
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(body, {
      'rentalProfileId': 7,
      'unitId': 42,
      'startTime': '2030-02-03T14:30:00',
      'endTime': '2030-02-03T16:10:00',
      'requesterUserAccountId': 12,
      'serviceFee': 15000,
      'notes': 'Please call on arrival.',
    });
    expect(booking['reference'], 'VB-test');
  });

  test(
    'viewing booking API shows business exception details from the backend',
    () async {
      final api = TanteApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'BUSINESS_EXCEPTION',
              'data':
                  'No agent is available for the requested time because of an overlapping active viewing.',
              'statusCode': 400,
            }),
            400,
          ),
        ),
      );

      await expectLater(
        api.createViewingBooking(
          rentalProfileId: 7,
          unitId: 42,
          startTime: DateTime(2030, 2, 3, 14, 30),
          requesterUserAccountId: 12,
          serviceFee: 15000,
          token: 'test-token',
        ),
        throwsA(
          isA<TanteApiException>().having(
            (error) => error.message,
            'message',
            'No agent is available for the requested time because of an overlapping active viewing.',
          ),
        ),
      );
    },
  );

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
        location: 'Mlimani',
        type: 'FLAT',
        minBedrooms: 2,
        minRent: '500000',
        maxRent: '1000000',
      );

      expect(requestUri.scheme, 'http');
      expect(requestUri.host, 'localhost');
      expect(requestUri.port, 8082);
      expect(requestUri.path, '/property-manager/v1/units');
      expect(requestUri.queryParameters['location'], 'Mlimani');
      expect(requestUri.queryParameters.containsKey('city'), isFalse);
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

  test('unit-details API parses the property manager response', () async {
    late Uri requestUri;
    final api = TanteApi(
      client: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 42,
              'unitNumber': 'A2',
              'rentalProfileId': 7,
              'numberOfBedrooms': 2,
              'numberOfBathrooms': 1,
              'numberParkingSpots': 1,
              'rentAmount': 850000,
              'type': 'FLAT',
              'status': 'AVAILABLE',
              'roomSize': 90,
              'sizeUnit': 'SQM',
              'floorNumber': 2,
              'building': {
                'name': 'Block A',
                'number': 1,
                'property': {
                  'name': 'Green Court',
                  'description': 'A bright apartment.',
                  'location': {
                    'address': {
                      'streetName': 'Mlimani Road',
                      'ward': 'Mlimani',
                      'city': 'Dar es Salaam',
                      'region': 'Dar es Salaam',
                      'country': 'Tanzania',
                    },
                  },
                },
              },
              'images': [
                {'id': 3, 'url': 'https://example.com/unit.jpg'},
              ],
            },
          }),
          200,
        );
      }),
    );

    final unit = await api.getUnitDetails(42);

    expect(requestUri.path, '/property-manager/v1/units/42');
    expect(unit.propertyName, 'Green Court');
    expect(unit.buildingName, 'Block A');
    expect(unit.address, contains('Mlimani'));
    expect(unit.images.single.url, 'https://example.com/unit.jpg');
    expect(unit.rentAmount, 850000);
  });

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

  testWidgets('quick search only offers location and unit type', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('Quick search'));
    await tester.pumpAndSettle();

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Unit type'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
  });

  testWidgets('tenant sign-in opens the tenant login form', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text("I'm a tenant"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Tante'), findsOneWidget);
    expect(find.text('Log in as Tenant'), findsOneWidget);
  });

  testWidgets('tenant home finishes loading the backend tenant profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TenantHomePage(
          session: const AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'Tenant',
          ),
          api: _FakeTanteApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome home, Jordan'), findsOneWidget);
    expect(find.text('No active lease found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('main-page sign-in continues to tenant home', (tester) async {
    await tester.pumpWidget(MyApp(api: _FakeTanteApi()));

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Tanzanian phone number'),
      '+255712345678',
    );
    await tester.enterText(find.bySemanticsLabel('Password'), 'password');
    await tester.tap(find.text('Log in as Tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome home, Jordan'), findsOneWidget);
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

  testWidgets('listing details opens the unit details page', (tester) async {
    await tester.pumpWidget(MyApp(api: _FakeTanteApi()));

    await tester.ensureVisible(find.text('Search homes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search homes'));
    await tester.pumpAndSettle();
    expect(find.text('1 place to explore'), findsOneWidget);

    await tester.ensureVisible(find.text('Green Court | Unit A2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green Court | Unit A2'));
    await tester.pumpAndSettle();

    expect(find.text('Home details'), findsOneWidget);
    expect(find.text('Green Court | Unit A2'), findsOneWidget);
    expect(find.text('Unit details'), findsOneWidget);
    expect(find.text('TSh 850,000 / month'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Agency'), findsOneWidget);
  });

  testWidgets('booking sign-in submits a viewing request', (tester) async {
    final api = _FakeTanteApi();
    await _openBookingRequest(tester, api);
    await _submitViewingRequest(tester);

    expect(api.requestedUnitId, 42);
    expect(api.requestedRequesterId, 42);
    expect(api.requestedServiceFee, 15000);
    expect(api.requestedStartTime, isNotNull);
    expect(find.textContaining('Viewing request sent'), findsOneWidget);
  });

  testWidgets('booking failure shows a centered message with Cancel', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..bookingFailureMessage = 'No agent is available at that time.';
    await _openBookingRequest(tester, api);
    await _submitViewingRequest(tester);

    expect(find.text('Viewing request failed'), findsOneWidget);
    expect(find.text('No agent is available at that time.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Viewing request failed'), findsNothing);
    expect(find.text('Home details'), findsOneWidget);
  });
}

Future<void> _enterPropertyText(
  WidgetTester tester,
  String fieldKey,
  String value,
) async {
  final field = find.byKey(ValueKey(fieldKey));
  for (var attempt = 0; attempt < 8 && field.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
  }
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  final editableText = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.enterText(editableText, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _openBookingRequest(WidgetTester tester, _FakeTanteApi api) async {
  await tester.pumpWidget(MyApp(api: api));
  await tester.ensureVisible(find.text('Search homes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Search homes'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Green Court | Unit A2'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Green Court | Unit A2'));
  await tester.pumpAndSettle();

  await tester.drag(find.byType(ListView).last, const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Sign in to schedule viewing'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in to schedule viewing'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.bySemanticsLabel('Tanzanian phone number'),
    '+255712345678',
  );
  await tester.enterText(find.bySemanticsLabel('Password'), 'password');
  await tester.tap(find.text('Log in as Tenant'));
  await tester.pumpAndSettle();

  expect(find.text('Request a viewing'), findsOneWidget);
  expect(find.text('Tante Rentals'), findsOneWidget);
  expect(find.text('Viewing fee: TSh 15,000'), findsOneWidget);
}

Future<void> _submitViewingRequest(WidgetTester tester) async {
  await tester.tap(find.text('Choose date and time'));
  await tester.pumpAndSettle();

  final today = DateTime.now();
  final viewingDate = today.add(const Duration(days: 2));
  if (viewingDate.month != today.month || viewingDate.year != today.year) {
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('${viewingDate.day}'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send request'));
  await tester.pumpAndSettle();
}

class _FakeTanteApi extends TanteApi {
  int? requestedUnitId;
  int? requestedRequesterId;
  double? requestedServiceFee;
  DateTime? requestedStartTime;
  String? bookingFailureMessage;

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
    required String location,
    required String type,
    required int minBedrooms,
    required String minRent,
    required String maxRent,
  }) async {
    return const RentalListingsPage(
      items: [
        RentalListing(
          id: 42,
          unitNumber: 'A2',
          bedrooms: 2,
          bathrooms: 1,
          rentAmount: 850000,
          type: 'FLAT',
          status: 'AVAILABLE',
          propertyName: 'Green Court',
          streetName: 'Mlimani Road',
          city: 'Dar es Salaam',
          region: 'Dar es Salaam',
        ),
      ],
      totalElements: 1,
    );
  }

  @override
  Future<RentalUnitDetails> getUnitDetails(int unitId) async {
    return const RentalUnitDetails(
      id: 42,
      unitNumber: 'A2',
      rentalProfileId: 7,
      bedrooms: 2,
      bathrooms: 1,
      parkingSpaces: 1,
      rentAmount: 850000,
      type: 'FLAT',
      status: 'AVAILABLE',
      roomSize: 90,
      sizeUnit: 'SQM',
      floorNumber: 2,
      buildingNumber: 1,
      buildingName: 'Block A',
      propertyName: 'Green Court',
      propertyDescription: 'A bright apartment.',
      address: ['Mlimani Road', 'Mlimani', 'Dar es Salaam'],
      images: [],
    );
  }

  @override
  Future<Map<String, dynamic>> getTenantDetails(
    int userId,
    String token,
  ) async {
    return {
      'id': 12,
      'userId': userId,
      'firstName': 'Jordan',
      'lastName': 'Smith',
      'email': 'jordan@example.com',
      'phoneNumber': '+255712345678',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTenantLeases(
    int tenantId,
    String token,
  ) async {
    return const [];
  }

  @override
  Future<AuthSession> signIn({
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    return AuthSession(
      phoneNumber: phoneNumber,
      token: 'test-token',
      userId: 42,
      role: role,
    );
  }

  @override
  Future<Map<String, dynamic>> getRentalProfileDetails(
    int rentalProfileId,
    String token,
  ) async {
    return {
      'id': rentalProfileId,
      'name': 'Tante Rentals',
      'phoneNumber': '+255712345678',
      'email': 'rentals@example.com',
      'viewingServiceFee': 15000,
      'type': 'BUSINESS',
    };
  }

  @override
  Future<Map<String, dynamic>> createViewingBooking({
    required int rentalProfileId,
    required int unitId,
    required DateTime startTime,
    required int requesterUserAccountId,
    required double serviceFee,
    required String token,
    String? notes,
  }) async {
    if (bookingFailureMessage != null) {
      throw TanteApiException(bookingFailureMessage!);
    }
    requestedUnitId = unitId;
    requestedRequesterId = requesterUserAccountId;
    requestedServiceFee = serviceFee;
    requestedStartTime = startTime;
    return {'id': 8, 'reference': 'VB-test'};
  }
}
