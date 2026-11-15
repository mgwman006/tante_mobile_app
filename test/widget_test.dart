import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tante/features/landlord/pages/create_property_page.dart';
import 'package:tante/features/landlord/pages/landlord_properties_page.dart';
import 'package:tante/features/landlord/pages/landlord_overview_page.dart';
import 'package:tante/features/landlord/pages/landlord_leases_page.dart';
import 'package:tante/features/landlord/pages/landlord_viewings_page.dart';
import 'package:tante/features/landlord/pages/lease_details_page.dart';
import 'package:tante/features/landlord/pages/property_details_page.dart';
import 'package:tante/features/landlord/dialogs/create_rental_profile_dialog.dart';
import 'package:tante/features/auth/complete_user_profile_page.dart';
import 'package:tante/features/landlord/widgets/lease_terms_editor.dart';
import 'package:tante/features/landlord/landlord_home.dart';
import 'package:tante/features/tenant/tenant_home.dart';
import 'package:tante/main.dart';
import 'package:tante/login.dart';
import 'package:tante/services/tante_api.dart';

void main() {
  test(
    'lease terms sanitizer preserves formatting and removes unsafe HTML',
    () {
      expect(
        sanitizeRichHtml(
          '<div onclick="run()">Lease <strong>terms</strong></div>'
          '<script>alert(1)</script><img src="https://invalid.example">',
        ),
        '<p>Lease <strong>terms</strong></p>',
      );
    },
  );

  testWidgets(
    'lease terms editor edits readable text and saves formatted HTML',
    (tester) async {
      String? savedTerms;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  savedTerms = await showDialog<String>(
                    context: context,
                    builder: (context) => const RichHtmlEditorDialog(html: ''),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bold'), findsOneWidget);
      expect(find.byTooltip('Bulleted list'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'New lease term');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();
      expect(controller.text, 'New lease term');

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('New lease term'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedTerms, '<p><strong>New lease term</strong></p>');
    },
  );

  testWidgets('lease terms editor loads formatted HTML as readable text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichHtmlEditorDialog(
            html:
                '<p>Existing <strong>terms</strong></p>'
                '<ul><li>First</li><li>Second</li></ul>',
          ),
        ),
      ),
    );

    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.text, 'Existing terms\n\u2022 First\n\u2022 Second');
    expect(controller.text, isNot(contains('<')));
  });

  testWidgets('lease terms editor stores readable numbered lists as HTML', (
    tester,
  ) async {
    String? savedTerms;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedTerms = await showDialog<String>(
                  context: context,
                  builder: (context) => const RichHtmlEditorDialog(html: ''),
                );
              },
              child: const Text('Open list editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open list editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First\nSecond');
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    await tester.tap(find.byTooltip('Numbered list'));
    await tester.pumpAndSettle();

    expect(controller.text, '1. First\n2. Second');
    expect(controller.text, isNot(contains('<li>')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(savedTerms, '<ol><li>First</li><li>Second</li></ol>');
  });

  test('lease API uses Rent Manager detail and update contracts', () async {
    final requests = <http.Request>[];
    final api = TanteApi(
      client: MockClient((request) async {
        requests.add(request);
        final data = request.url.path.endsWith('/rent/summary/15')
            ? {
                'totalExpectedAmount': 0,
                'totalPaidAmount': 0,
                'totalOutstandingAmount': 0,
                'paymentBlocks': [],
              }
            : {
                'id': 15,
                'rent': {
                  'amount': 850000,
                  'currency': 'TZS',
                  'frequency': 'MONTHLY',
                },
                'status': 'PENDING',
                'startDate': '2026-01-01',
                'endDate': '2026-12-31',
              };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );

    await api.getLeaseDetails(15, 'test-token');
    await api.updateLeaseDates(
      leaseId: 15,
      startDate: '2026-02-01',
      endDate: '2027-01-31',
      token: 'test-token',
    );
    await api.updateLeaseRent(
      leaseId: 15,
      amount: 950000,
      currency: 'TZS',
      frequency: 'MONTHLY',
      fullLeasePaymentRequired: false,
      token: 'test-token',
    );
    await api.updateLeaseTerms(
      leaseId: 15,
      leaseTerms: 'Updated terms',
      token: 'test-token',
    );
    await api.getLeaseRentSummary(15, 'test-token');

    expect(requests.map((request) => request.url.path), [
      '/rent-manager/v1/leases/15',
      '/rent-manager/v1/leases/15/dates',
      '/rent-manager/v1/leases/15/rent',
      '/rent-manager/v1/leases/15/terms',
      '/rent-manager/v1/leases/rent/summary/15',
    ]);
    expect(requests.first.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(requests[1].body), {
      'startDate': '2026-02-01',
      'endDate': '2027-01-31',
    });
    expect(jsonDecode(requests[2].body), {
      'rent': {'amount': 950000, 'currency': 'TZS', 'frequency': 'MONTHLY'},
      'fullLeasePaymentRequired': false,
    });
    expect(jsonDecode(requests[3].body), {'leaseTerms': 'Updated terms'});
  });

  test(
    'lease unit assignment and payment APIs match backend contracts',
    () async {
      final requests = <http.Request>[];
      final api = TanteApi(
        client: MockClient((request) async {
          requests.add(request);
          final data = switch (request.url.path) {
            '/property-manager/v1/properties/rental-profile/7' => [
              {
                'name': 'Green Court',
                'buildings': [
                  {
                    'name': 'Block A',
                    'units': [
                      {
                        'id': 42,
                        'unitNumber': 'A2',
                        'type': 'FLAT',
                        'status': 'AVAILABLE',
                        'rentAmount': 850000,
                      },
                      {
                        'id': 43,
                        'unitNumber': 'A3',
                        'type': 'FLAT',
                        'status': 'OCCUPIED',
                        'rentAmount': 900000,
                      },
                    ],
                  },
                ],
              },
            ],
            '/rent-manager/v1/payment-blocks/rental-profile/7/record-payment' =>
              'Payment recorded successfully',
            _ => {
              'id': 15,
              'unitId': 42,
              'rent': {
                'amount': 850000,
                'currency': 'TZS',
                'frequency': 'MONTHLY',
              },
              'status': 'PENDING',
              'startDate': '2026-01-01',
              'endDate': '2026-12-31',
            },
          };
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );

      final units = await api.getAvailableLeaseUnits(7, 'test-token');
      final updatedLease = await api.assignLeaseUnit(
        leaseId: 15,
        unitId: 42,
        token: 'test-token',
      );
      final confirmation = await api.recordLeasePayment(
        rentalProfileId: 7,
        paymentBlockId: 19,
        amount: 850000,
        currency: 'TZS',
        payerUserId: 5,
        method: 'CASH',
        reference: 'RCPT-19',
        token: 'test-token',
        note: 'October rent',
      );

      expect(units, hasLength(1));
      expect(units.single.id, 42);
      expect(updatedLease['unitId'], 42);
      expect(confirmation, 'Payment recorded successfully');
      expect(requests.map((request) => request.url.path), [
        '/property-manager/v1/properties/rental-profile/7',
        '/rent-manager/v1/leases/15/unit',
        '/rent-manager/v1/payment-blocks/rental-profile/7/record-payment',
      ]);
      expect(jsonDecode(requests[1].body), {'unitId': 42});
      expect(jsonDecode(requests[2].body), {
        'paymentBlockId': 19,
        'amount': 850000,
        'currency': 'TZS',
        'payerUserId': 5,
        'method': 'CASH',
        'reference': 'RCPT-19',
        'note': 'October rent',
      });
      expect(requests.last.headers['authorization'], 'Bearer test-token');
    },
  );

  testWidgets('lease details show six tabs and restrict ACTIVE editing', (
    tester,
  ) async {
    final api = _FakeTanteApi()..leaseStatus = 'ACTIVE';
    await tester.pumpWidget(
      MaterialApp(
        home: LeaseDetailsPage(leaseId: 15, token: 'test-token', api: api),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Tenant',
      'Unit',
      'Dates',
      'Rent',
      'Terms and conditions',
      'Payment',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Dates').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lease-edit-restricted')), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('lease cards navigate to lease details', (tester) async {
    final api = _FakeTanteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordLeasesPage(
            leases: const [
              {'id': 15, 'referenceNumber': 'LEASE-15', 'status': 'PENDING'},
            ],
            api: api,
            token: 'test-token',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Lease LEASE-15'));
    await tester.pumpAndSettle();

    expect(find.text('Lease LEASE-15'), findsOneWidget);
    expect(find.text('Dates'), findsOneWidget);
  });

  testWidgets('landlord can create a lease from the leases page', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = TanteApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path ==
            '/property-manager/v1/properties/rental-profile/7') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }
        if (request.url.path == '/rent-manager/v1/leases/landlord') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 27,
                'referenceNumber': 'LS-YR2026-000027',
                'status': 'PENDING_TENANT_APPROVAL',
                'startDate': '2026-12-01',
                'endDate': '2027-11-30',
                'rent': {
                  'amount': 850000,
                  'currency': 'TZS',
                  'frequency': 'MONTHLY',
                },
                'fullLeasePaymentRequired': false,
                'tenant': null,
                'invitations': [],
              },
            }),
            201,
          );
        }
        return http.Response('Unexpected request: ${request.url.path}', 500);
      }),
    );
    Map<String, dynamic>? createdLease;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordLeasesPage(
            leases: const [],
            api: api,
            token: 'test-token',
            rentalProfileId: 7,
            onLeaseCreated: (lease) => createdLease = lease,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('create-lease-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lease-tenant-first-name')),
      'Jordan',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lease-tenant-last-name')),
      'Smith',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lease-tenant-phone')),
      '+255712345678',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('No available units to select.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lease-rent-amount')),
      '850000',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final startDate = DateUtils.dateOnly(DateTime.now());
    final endDate = startDate.add(const Duration(days: 1));
    await tester.tap(find.byKey(const ValueKey('lease-start-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lease-end-date-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create lease'));
    await tester.pumpAndSettle();

    expect(find.text('Lease reference: LS-YR2026-000027'), findsOneWidget);
    await tester.tap(find.text('Go to list'));
    await tester.pumpAndSettle();

    expect(createdLease?['id'], 27);
    final createRequest = requests.singleWhere(
      (request) => request.url.path == '/rent-manager/v1/leases/landlord',
    );
    expect(createRequest.method, 'POST');
    expect(
      createRequest.headers['Authorization']?.startsWith('Bearer '),
      isTrue,
    );
    expect(jsonDecode(createRequest.body), {
      'rentalProfileId': 7,
      'tenantFirstName': 'Jordan',
      'tenantLastName': 'Smith',
      'tenantPhoneNumber': '+255712345678',
      'startDate':
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'endDate':
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'rent': {
        'id': 0,
        'amount': 850000,
        'currency': 'TZS',
        'frequency': 'MONTHLY',
      },
      'leaseTerms': '',
      'fullLeasePaymentRequired': false,
    });
  });

  testWidgets('pending lease dates can be edited and saved', (tester) async {
    final api = _FakeTanteApi()..leaseStatus = 'PENDING';
    await tester.pumpWidget(
      MaterialApp(
        home: LeaseDetailsPage(leaseId: 15, token: 'test-token', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dates').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '2026-02-01');
    await tester.enterText(fields.at(1), '2027-01-31');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(api.updatedLeaseStartDate, '2026-02-01');
    expect(api.updatedLeaseEndDate, '2027-01-31');
    expect(find.text('Lease updated successfully.'), findsOneWidget);
  });

  testWidgets('unassigned lease can select and assign an available unit', (
    tester,
  ) async {
    final api = _FakeTanteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: LeaseDetailsPage(
          leaseId: 15,
          token: 'test-token',
          api: api,
          rentalProfileId: 7,
          payerUserId: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign a unit'));
    await tester.pumpAndSettle();

    expect(find.text('Unit A2'), findsOneWidget);
    await tester.tap(find.text('Unit A2'));
    await tester.pumpAndSettle();

    expect(api.assignedUnitId, 42);
    expect(find.text('Unit A2'), findsOneWidget);
    expect(find.text('No unit assigned'), findsNothing);
  });

  testWidgets('landlord can record a full payment block payment', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..leaseStatus = 'ACTIVE'
      ..paymentBlocks = [
        {
          'id': 19,
          'amount': 850000,
          'paidAmount': 0,
          'outstandingAmount': 850000,
          'startDate': '2026-10-01',
          'endDate': '2026-10-31',
          'dueDate': '2026-10-05',
          'status': 'UNPAID',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: LeaseDetailsPage(
          leaseId: 15,
          token: 'test-token',
          api: api,
          rentalProfileId: 7,
          payerUserId: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Payment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment').first);
    await tester.pumpAndSettle();
    expect(find.text('Record payment'), findsOneWidget);
    await tester.ensureVisible(find.text('Record payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'RCPT-19');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(api.recordedPaymentBlockId, 19);
    expect(api.recordedPaymentAmount, 850000);
    expect(api.recordedPaymentReference, 'RCPT-19');
    expect(api.recordedPaymentUserId, 5);
    expect(find.text('Payment recorded successfully.'), findsOneWidget);
  });

  testWidgets('landlord lease cards follow the property card layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordLeasesPage(
            leases: const [
              {
                'id': 42,
                'referenceNumber': 'LEASE-42',
                'status': 'PENDING_TENANT_APPROVAL',
                'unitId': 12,
                'startDate': '2026-01-01',
                'endDate': '2026-12-31',
                'rent': {
                  'amount': 850000,
                  'currency': 'TZS',
                  'frequency': 'MONTHLY',
                },
              },
            ],
          ),
        ),
      ),
    );

    expect(find.text('Lease LEASE-42'), findsOneWidget);
    expect(find.text('Pending Tenant Approval'), findsOneWidget);
    expect(find.text('Term: 2026-01-01 – 2026-12-31'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    final statusChip = tester.widget<Chip>(
      find.ancestor(
        of: find.text('Pending Tenant Approval'),
        matching: find.byType(Chip),
      ),
    );
    expect(
      statusChip.backgroundColor,
      Colors.orange.shade800.withValues(alpha: .12),
    );
  });

  testWidgets('landlord leases can be filtered by status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordLeasesPage(
            leases: const [
              {
                'id': 42,
                'referenceNumber': 'LEASE-ACTIVE',
                'status': 'ACTIVE',
                'startDate': '2026-01-01',
                'endDate': '2026-12-31',
              },
              {
                'id': 43,
                'referenceNumber': 'LEASE-PENDING',
                'status': 'PENDING_TENANT_APPROVAL',
                'startDate': '2026-02-01',
                'endDate': '2027-01-31',
              },
            ],
          ),
        ),
      ),
    );

    expect(find.text('Lease LEASE-ACTIVE'), findsOneWidget);
    expect(find.text('Lease LEASE-PENDING'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lease-status-filter')));
    await tester.pumpAndSettle();
    for (final status in [
      'Active',
      'Ended',
      'Terminated',
      'Pending',
      'Pending Landlord Approval',
      'Pending Tenant Approval',
    ]) {
      expect(find.text(status), findsWidgets);
    }
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();

    expect(find.text('Lease LEASE-ACTIVE'), findsOneWidget);
    expect(find.text('Lease LEASE-PENDING'), findsNothing);
    expect(find.text('No leases match the selected status.'), findsNothing);
  });

  testWidgets('landlord back button returns to the previous visited page', (
    tester,
  ) async {
    final api = _FakeTanteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: LandlordHomePage(
          session: AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'LANDLORD',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tante Rentals'));
    await tester.pumpAndSettle();
    expect(find.text('Your rental overview'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage leases'));
    await tester.pumpAndSettle();
    expect(
      find.text('Agreements managed through Rent Manager.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Viewings').last);
    await tester.pumpAndSettle();
    expect(find.text('Viewing bookings'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.text('Agreements managed through Rent Manager.'),
      findsOneWidget,
    );
    expect(find.text('Viewing bookings'), findsNothing);

    await tester.tap(find.text('Viewings').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.text('Agreements managed through Rent Manager.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landlord overview displays viewing booking count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordOverviewPage(
            profileName: 'Tante Rentals',
            propertyCount: 4,
            leaseCount: 2,
            viewingCount: 3,
            onOpenProperties: () {},
            onOpenLeases: () {},
            onOpenViewings: () {},
          ),
        ),
      ),
    );

    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Leases'), findsOneWidget);
    expect(find.text('Viewing bookings'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('landlord properties displays structured property addresses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LandlordPropertiesPage(
          onAddProperty: () {},
          onOpenProperty: (_) {},
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
          onOpenProperty: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();

    expect(addTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('property card opens the selected property callback', (
    tester,
  ) async {
    Map<String, dynamic>? openedProperty;
    await tester.pumpWidget(
      MaterialApp(
        home: LandlordPropertiesPage(
          properties: const [
            {
              'id': 5,
              'name': 'Green Court',
              'type': 'COMPOUND',
              'location': <String, dynamic>{},
            },
          ],
          onAddProperty: () {},
          onOpenProperty: (property) => openedProperty = property,
        ),
      ),
    );

    await tester.tap(find.text('Green Court'));

    expect(openedProperty?['id'], 5);
  });

  test('property-details API parses nested buildings and units', () async {
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
              'id': 5,
              'name': 'Green Court',
              'type': 'COMPOUND',
              'buildings': [
                {
                  'id': 8,
                  'number': 1,
                  'name': 'Block A',
                  'numberOfFloors': 3,
                  'units': [
                    {
                      'id': 12,
                      'unitNumber': 'A1',
                      'numberOfBedrooms': 2,
                      'numberOfBathrooms': 1,
                      'rentAmount': 850000,
                      'type': 'FLAT',
                      'isListed': false,
                    },
                  ],
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final property = await api.getPropertyDetails(5, 'test-token');

    expect(requestUri.path, '/property-manager/v1/properties/5');
    expect(authorization, startsWith('Bearer '));
    expect((property['buildings'] as List).single['units'], hasLength(1));
  });

  test('unit listing status API advertises a unit', () async {
    late http.Request request;
    final api = TanteApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'success': true, 'data': true}), 200);
      }),
    );

    final isListed = await api.advertiseUnit(unitId: 12, token: 'test-token');

    expect(request.method, 'PATCH');
    expect(request.url.path, '/property-manager/v1/units/12/listing/status');
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(jsonDecode(request.body), {'isListed': true});
    expect(isListed, isTrue);
  });

  testWidgets('property details shows buildings and advertises a unit', (
    tester,
  ) async {
    final api = _FakeTanteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsPage(
          propertyId: 5,
          rentalProfileId: 7,
          api: api,
          token: 'test-token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Block A'), findsOneWidget);
    expect(find.text('Green living'), findsOneWidget);
    expect(find.text('Unit A1'), findsOneWidget);
    expect(find.textContaining('2 bed · 1 bath'), findsOneWidget);
    expect(find.text('Advertise'), findsOneWidget);
    await tester.tap(find.text('Advertise'));
    await tester.pumpAndSettle();

    expect(api.updatedUnitId, 12);
    expect(api.updatedListingStatus, isTrue);
    expect(find.text('Advertised'), findsOneWidget);
    expect(find.text('Remove advert'), findsNothing);
    expect(find.text('Advertise'), findsNothing);
  });

  testWidgets(
    'property details retries a failed load without setState errors',
    (tester) async {
      final api = _FakeTanteApi()..failPropertyDetailsOnce = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PropertyDetailsPage(
            propertyId: 5,
            rentalProfileId: 7,
            api: api,
            token: 'test-token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary property details failure.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(api.propertyDetailsRequests, 2);
      expect(find.text('Block A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('create unit API sends the backend contract', () async {
    late http.Request request;
    final api = TanteApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 12, 'unitNumber': 'A2', 'isListed': false},
          }),
          201,
        );
      }),
    );

    final unit = await api.createUnit(
      buildingId: 8,
      rentalProfileId: 7,
      token: 'test-token',
      unitNumber: ' A2 ',
      numberOfBedrooms: 2,
      numberOfBathrooms: 1,
      numberParkingSpots: 1,
      rentAmount: 850000,
      type: 'FLAT',
      roomSize: 90,
      sizeUnit: 'SQM',
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;

    expect(request.method, 'POST');
    expect(request.url.path, '/property-manager/v1/units/building/8');
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(body, {
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
    });
    expect(unit['unitNumber'], 'A2');
  });

  testWidgets('building can add a unit and show it in the unit list', (
    tester,
  ) async {
    final api = _FakeTanteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PropertyDetailsPage(
          propertyId: 5,
          rentalProfileId: 7,
          api: api,
          token: 'test-token',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add unit'));
    await tester.pumpAndSettle();

    await _enterUnitText(tester, 'new-unit-number', 'A2');
    await _enterUnitText(tester, 'new-unit-rent', '950000');
    await tester.ensureVisible(find.text('Create unit'));
    await tester.tap(find.text('Create unit'));
    await tester.pumpAndSettle();

    expect(api.createdBuildingId, 8);
    expect(api.createdRentalProfileId, 7);
    expect(api.createdUnitNumber, 'A2');
    expect(api.createdUnitRent, 950000);
    expect(find.text('Unit A2'), findsOneWidget);
    expect(find.textContaining('TSh 950,000 / month'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Add description'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add description'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'A sunny home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create property'));
    await tester.tap(find.text('Create property'));
    await tester.pumpAndSettle();

    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['createdByUserId'], 42);
    expect(body['name'], 'Green Court');
    expect(body['type'], 'STAND_ALONE_HOUSE');
    expect(body['description'], '<p>A sunny home</p>');
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
    await tester.tap(find.byTooltip('Back'));
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
    expect(profile['viewingServiceFee'], 15000);
  });

  testWidgets('rental profile creation submits the viewing service fee', (
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
              'id': 7,
              'name': 'Tante Rentals',
              'viewingServiceFee': 25000,
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
              onPressed: () => showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) =>
                    CreateRentalProfileDialog(api: api, session: session),
              ),
              child: const Text('Open profile form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open profile form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Tante Rentals');
    await tester.enterText(find.byType(TextFormField).at(3), '25000');
    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();

    expect(request.method, 'POST');
    expect(request.url.path, '/rent-manager/v1/rentalprofiles');
    expect(request.headers['Authorization']?.startsWith('Bearer '), isTrue);
    expect(jsonDecode(request.body), {
      'name': 'Tante Rentals',
      'phoneNumber': '+255712345678',
      'email': null,
      'type': 'INDIVIDUAL',
      'viewingServiceFee': 25000,
      'userId': 42,
    });
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
    'landlord viewing APIs follow the rent-manager routes and DTOs',
    () async {
      final requests = <http.Request>[];
      final api = TanteApi(
        client: MockClient((request) async {
          requests.add(request);
          final action = request.url.path.split('/').last;
          final booking = <String, dynamic>{
            'id': 99,
            'reference': 'VB-99',
            'rentalProfileId': 7,
            'unitId': 42,
            'startTime': '2030-02-03T14:30:00',
            'endTime': '2030-02-03T16:10:00',
            'requesterUserId': 12,
            'status': switch (action) {
              'approve' => 'CONFIRMED',
              'reject' => 'REJECTED',
              'cancel' => 'CANCELLED',
              'outcome' => 'CLOSED',
              _ => 'PENDING',
            },
            'serviceFee': 15000,
            'paymentStatus': 'PAID',
          };
          if (action == 'outcome') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            booking['outcome'] = {
              'id': 5,
              'bookingId': 99,
              'type': body['outcome'],
              'notes': body['notes'],
              'recordedAt': '2030-02-03T16:10:00',
            };
          }
          final data = request.method == 'GET' ? [booking] : booking;
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );

      final bookings = await api.getViewingBookings(7, 'test-token');
      final approved = await api.approveViewingBooking(
        bookingId: 99,
        token: 'test-token',
      );
      final rejected = await api.rejectViewingBooking(
        bookingId: 99,
        token: 'test-token',
      );
      final cancelled = await api.cancelViewingBooking(
        bookingId: 99,
        token: 'test-token',
      );
      final closed = await api.recordViewingOutcome(
        bookingId: 99,
        outcome: 'COMPLETED',
        notes: 'Viewing completed.',
        token: 'test-token',
      );

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'GET /rent-manager/v1/viewings/bookings/by-rental-profile/7',
          'PATCH /rent-manager/v1/viewings/bookings/99/approve',
          'PATCH /rent-manager/v1/viewings/bookings/99/reject',
          'PATCH /rent-manager/v1/viewings/bookings/99/cancel',
          'PATCH /rent-manager/v1/viewings/bookings/99/outcome',
        ],
      );
      expect(
        requests.every(
          (request) =>
              request.headers['Authorization']?.startsWith('Bearer ') == true,
        ),
        isTrue,
      );
      expect(
        requests.skip(1).take(3).every((request) => request.body.isEmpty),
        isTrue,
      );
      expect(jsonDecode(requests.last.body), {
        'outcome': 'COMPLETED',
        'notes': 'Viewing completed.',
      });
      expect(bookings.single['reference'], 'VB-99');
      expect(approved['status'], 'CONFIRMED');
      expect(rejected['status'], 'REJECTED');
      expect(cancelled['status'], 'CANCELLED');
      expect((closed['outcome'] as Map)['type'], 'COMPLETED');
    },
  );

  test('tenant dashboard APIs follow Rent Manager contracts', () async {
    final requests = <http.Request>[];
    const invitationToken = '6b3f3c9b-4a2d-4c72-8b5a-45b4b1f26d78';
    final invitation = {
      'id': 8,
      'leaseId': 15,
      'firstName': 'Jordan',
      'lastName': 'Smith',
      'phoneNumber': '+255712345678',
      'email': 'jordan@example.com',
      'invitationToken': invitationToken,
      'status': 'PENDING',
      'expiresAt': '2030-02-01T10:00:00',
    };
    final booking = {
      'id': 99,
      'reference': 'VB-99',
      'rentalProfileId': 7,
      'unitId': 42,
      'startTime': '2030-02-03T14:30:00',
      'endTime': '2030-02-03T16:10:00',
      'requesterUserId': 42,
      'status': 'PENDING',
      'serviceFee': 15000,
      'paymentStatus': 'AWAITING_PAYMENT',
    };
    final api = TanteApi(
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final data = path.contains('/lease-invitations/phone/')
            ? [invitation]
            : path.endsWith('/tenant/accept')
            ? null
            : path.contains('/lease-invitations/$invitationToken')
            ? invitation
            : path.endsWith('/viewings/bookings/by-requester/42')
            ? [booking]
            : path.endsWith('/payment-blocks/tenant/12/record-payment')
            ? 'Payment recorded successfully'
            : throw StateError('Unexpected URL ${request.url}');
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );

    final invitations = await api.getTenantInvitations(
      '+255712345678',
      'test-token',
    );
    final fetchedInvitation = await api.getTenantInvitation(
      invitationToken,
      'test-token',
    );
    await api.acceptTenantLeaseInvitation(
      invitationToken: invitationToken,
      userId: 42,
      token: 'test-token',
    );
    final bookings = await api.getTenantViewingBookings(42, 'test-token');
    final confirmation = await api.recordTenantLeasePayment(
      tenantId: 12,
      paymentBlockId: 5,
      amount: 850000,
      currency: 'TZS',
      payerUserId: 42,
      method: 'CASH',
      reference: 'RCPT-5',
      note: 'March rent',
      token: 'test-token',
    );

    expect(invitations.single['id'], 8);
    expect(fetchedInvitation['leaseId'], 15);
    expect(bookings.single['reference'], 'VB-99');
    expect(confirmation, 'Payment recorded successfully');
    expect(requests.first.method, 'GET');
    expect(
      requests.first.url.path.startsWith(
        '/rent-manager/v1/lease-invitations/phone/',
      ),
      isTrue,
    );
    expect(
      requests
          .skip(1)
          .map((request) => '${request.method} ${request.url.path}'),
      [
        'GET /rent-manager/v1/lease-invitations/$invitationToken',
        'POST /rent-manager/v1/lease-invitations/$invitationToken/tenant/accept',
        'GET /rent-manager/v1/viewings/bookings/by-requester/42',
        'POST /rent-manager/v1/payment-blocks/tenant/12/record-payment',
      ],
    );
    expect(requests.first.url.path.endsWith('255712345678'), isTrue);
    expect(requests[2].url.queryParameters['userId'], '42');
    expect(jsonDecode(requests.last.body), {
      'paymentBlockId': 5,
      'amount': 850000,
      'currency': 'TZS',
      'payerUserId': 42,
      'method': 'CASH',
      'reference': 'RCPT-5',
      'note': 'March rent',
    });
  });

  testWidgets('landlord viewing bookings enforce payment and record outcomes', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..viewingBookings = [
        _fakeViewingBooking(id: 99, status: 'PENDING', paymentStatus: 'PAID'),
        _fakeViewingBooking(
          id: 100,
          status: 'PENDING',
          paymentStatus: 'AWAITING_PAYMENT',
        ),
        _fakeViewingBooking(
          id: 101,
          status: 'CONFIRMED',
          paymentStatus: 'PAID',
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordViewingsPage(
            api: api,
            rentalProfileId: 7,
            rentalProfileName: 'Tante Rentals',
            token: 'test-token',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Viewing bookings'), findsOneWidget);
    expect(find.text('User #12'), findsWidgets);
    final approveForUnpaid = find.descendant(
      of: find.ancestor(
        of: find.text('Unit #100'),
        matching: find.byType(Card),
      ),
      matching: find.widgetWithText(FilledButton, 'Approve'),
    );
    expect(tester.widget<FilledButton>(approveForUnpaid).onPressed, isNull);

    final paidBookingCard = find.ancestor(
      of: find.text('Unit #99'),
      matching: find.byType(Card),
    );
    final paidBookingApprove = find.descendant(
      of: paidBookingCard,
      matching: find.widgetWithText(FilledButton, 'Approve'),
    );
    await tester.ensureVisible(paidBookingApprove);
    await tester.tap(paidBookingApprove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();
    expect(api.updatedViewingAction, 'approve');
    expect(find.text('Confirmed'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Record outcome').first);
    await tester.tap(find.text('Record outcome').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'Viewing completed.',
    );
    await tester.tap(find.text('Save outcome'));
    await tester.pumpAndSettle();

    expect(api.recordedViewingOutcome, 'COMPLETED');
    expect(api.recordedViewingNotes, 'Viewing completed.');
    expect(
      find.textContaining('Completed — Viewing completed.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landlord viewing list shows backend errors and can retry', (
    tester,
  ) async {
    int? loadedBookingCount;
    final api = _FakeTanteApi()
      ..viewingBookingsFailure = 'Viewing bookings are temporarily unavailable.'
      ..viewingBookings = [
        _fakeViewingBooking(id: 99, status: 'PENDING', paymentStatus: 'PAID'),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LandlordViewingsPage(
            api: api,
            rentalProfileId: 7,
            rentalProfileName: 'Tante Rentals',
            token: 'test-token',
            onBookingsLoaded: (count) => loadedBookingCount = count,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Viewing bookings are temporarily unavailable.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('VB-99'), findsOneWidget);
    expect(loadedBookingCount, 1);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Find a property'), findsOneWidget);
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

  testWidgets('tenant back button returns to the previously visited tab', (
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

    await tester.tap(find.text('My rent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leases').last);
    await tester.pumpAndSettle();
    expect(find.text('Your agreements and key dates.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      find.text('Rent details from your active lease agreements.'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your rental information, all together.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant lease list filters ended leases and opens details', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..tenantLeases = [
        {'id': 15, 'referenceNumber': 'ACTIVE-15', 'status': 'ACTIVE'},
        {'id': 16, 'referenceNumber': 'ENDED-16', 'status': 'ENDED'},
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: TenantHomePage(
          session: const AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'Tenant',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leases').last);
    await tester.pumpAndSettle();

    expect(find.text('Lease ACTIVE-15'), findsOneWidget);
    expect(find.text('Lease ENDED-16'), findsNothing);
    await tester.tap(find.text('Ended'));
    await tester.pumpAndSettle();
    expect(find.text('Lease ENDED-16'), findsOneWidget);
    expect(find.text('Lease ACTIVE-15'), findsNothing);

    await tester.tap(find.text('Lease ENDED-16'));
    await tester.pumpAndSettle();
    expect(find.text('Lease LEASE-16'), findsWidgets);
  });

  testWidgets('tenant can inspect and accept a lease invitation', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..tenantInvitations = [
        {
          'id': 8,
          'leaseId': 15,
          'invitationToken': 'invitation-15',
          'status': 'PENDING',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: TenantHomePage(
          session: const AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'Tenant',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lease invitations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lease 15'));
    await tester.pumpAndSettle();
    expect(find.text('Accept invitation'), findsOneWidget);

    await tester.ensureVisible(find.text('Accept invitation'));
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(api.acceptedInvitationToken, 'invitation-15');
  });

  testWidgets('tenant dashboard opens viewing history with colored statuses', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..tenantViewingBookings = [
        _fakeViewingBooking(
          id: 99,
          status: 'CONFIRMED',
          paymentStatus: 'AWAITING_PAYMENT',
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: TenantHomePage(
          session: const AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'Tenant',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viewing bookings').first);
    await tester.pumpAndSettle();

    expect(find.text('VB-99'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Awaiting Payment'), findsOneWidget);
  });

  testWidgets('tenant lease details load payment schedule and record payment', (
    tester,
  ) async {
    final api = _FakeTanteApi()
      ..tenantLeases = [
        {'id': 15, 'referenceNumber': 'LEASE-15', 'status': 'ACTIVE'},
      ]
      ..paymentBlocks = [
        {
          'id': 5,
          'amount': 850000,
          'paidAmount': 0,
          'outstandingAmount': 850000,
          'startDate': '2026-01-01',
          'endDate': '2026-01-31',
          'dueDate': '2026-01-01',
          'status': 'UNPAID',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: TenantHomePage(
          session: const AuthSession(
            phoneNumber: '+255712345678',
            token: 'test-token',
            userId: 42,
            role: 'Tenant',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My rent').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lease LEASE-15'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Payment schedule'), findsOneWidget);

    await tester.ensureVisible(find.text('Record payment'));
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'RCPT-5');
    await tester.tap(find.text('Submit payment'));
    await tester.pumpAndSettle();

    expect(api.recordedTenantPaymentBlockId, 5);
    expect(api.recordedTenantPaymentAmount, 850000);
    expect(api.recordedTenantPaymentUserId, 42);
    expect(api.recordedTenantPaymentReference, 'RCPT-5');
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
    await tester.ensureVisible(find.text('Log in as Tenant'));
    await tester.tap(find.text('Log in as Tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome home, Jordan'), findsOneWidget);
  });

  testWidgets('successful sign-in creates a missing user profile', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = TanteApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth-manager/v1/auth') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'jwtToken': 'account-token'},
            }),
            200,
          );
        }
        if (request.url.path == '/auth-manager/v1/users/0712345678') {
          return http.Response(
            jsonEncode({'success': false, 'message': 'User not found'}),
            404,
          );
        }
        if (request.url.path == '/auth-manager/v1/users') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 58,
                'firstName': 'Jordan',
                'lastName': 'Smith',
                'phoneNumber': '0712345678',
                'memberships': [],
              },
            }),
            201,
          );
        }
        return http.Response('Unexpected request: ${request.url.path}', 500);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Login(api: api),
        onGenerateRoute: (settings) {
          if (settings.name != '/complete-user-profile') return null;
          final args = settings.arguments! as CompleteUserProfileRouteArgs;
          return MaterialPageRoute<AuthSession>(
            builder: (_) => CompleteUserProfilePage(
              api: api,
              phoneNumber: args.phoneNumber,
              token: args.token,
              role: args.role,
            ),
          );
        },
        routes: {
          '/home': (context) {
            final session =
                ModalRoute.of(context)!.settings.arguments! as AuthSession;
            return Scaffold(body: Text('Signed in user ${session.userId}'));
          },
        },
      ),
    );

    await tester.enterText(
      find.bySemanticsLabel('Tanzanian phone number'),
      '0712345678',
    );
    await tester.enterText(find.bySemanticsLabel('Password'), 'password');
    await tester.ensureVisible(find.text('Log in as Landlord'));
    await tester.tap(find.text('Log in as Landlord'));
    await tester.pumpAndSettle();

    expect(find.text('How can we address you?'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Jordan');
    await tester.enterText(find.byType(TextFormField).last, 'Smith');
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in user 58'), findsOneWidget);
    expect(requests, hasLength(3));
    expect(requests.first.headers['Authorization'], isNull);
    expect(requests[1].headers['Authorization']?.startsWith('Bearer '), isTrue);
    expect(requests[2].method, 'POST');
    expect(requests[2].url.path, '/auth-manager/v1/users');
    expect(requests[2].headers['Authorization']?.startsWith('Bearer '), isTrue);
    expect(jsonDecode(requests[2].body), {
      'firstName': 'Jordan',
      'lastName': 'Smith',
      'phoneNumber': '0712345678',
    });
  });

  testWidgets('unregistered user can create an account from sign-in', (
    tester,
  ) async {
    late http.Request request;
    final api = TanteApi(
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'phoneNumber': '0712345678'},
          }),
          201,
        );
      }),
    );
    await tester.pumpWidget(MyApp(api: api));

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Tanzanian phone number'),
      '0712345678',
    );
    await tester.ensureVisible(find.text('New to Tante? Create an account'));
    await tester.tap(find.text('New to Tante? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Join Tante'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    final createAccountButton = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(request.url.path, '/auth-manager/v1/auth/account');
    expect(request.headers['Authorization'], isNull);
    expect(jsonDecode(request.body), {
      'phoneNumber': '0712345678',
      'passWord': 'password',
    });
    expect(find.text('Log in as Tenant'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      '0712345678',
    );
    expect(
      find.text('Account created. Sign in with your new account.'),
      findsOneWidget,
    );
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
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Homes for rent'), findsOneWidget);
    expect(find.text('1 place to explore'), findsOneWidget);
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

Map<String, dynamic> _fakeViewingBooking({
  required int id,
  required String status,
  required String paymentStatus,
}) {
  return {
    'id': id,
    'reference': 'VB-$id',
    'rentalProfileId': 7,
    'unitId': id,
    'startTime': '2030-02-03T14:30:00',
    'endTime': '2030-02-03T16:10:00',
    'requesterUserId': 12,
    'status': status,
    'serviceFee': 15000,
    'paymentStatus': paymentStatus,
  };
}

Future<void> _enterUnitText(
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
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    value,
  );
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
  await tester.ensureVisible(find.text('Log in as Tenant'));
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
  int? updatedUnitId;
  bool? updatedListingStatus;
  int? createdBuildingId;
  int? createdRentalProfileId;
  int? assignedUnitId;
  int? recordedPaymentBlockId;
  double? recordedPaymentAmount;
  int? recordedPaymentUserId;
  String? recordedPaymentReference;
  String? createdUnitNumber;
  double? createdUnitRent;
  bool failPropertyDetailsOnce = false;
  int propertyDetailsRequests = 0;
  List<Map<String, dynamic>> viewingBookings = const [];
  String? viewingBookingsFailure;
  String? updatedViewingAction;
  String? recordedViewingOutcome;
  String? recordedViewingNotes;
  String leaseStatus = 'PENDING';
  String? updatedLeaseStartDate;
  String? updatedLeaseEndDate;
  List<Map<String, dynamic>> paymentBlocks = const [];
  int paymentSummaryRequests = 0;
  List<Map<String, dynamic>> tenantLeases = const [];
  List<Map<String, dynamic>> tenantInvitations = const [];
  List<Map<String, dynamic>> tenantViewingBookings = const [];
  String? acceptedInvitationToken;
  int? recordedTenantPaymentBlockId;
  double? recordedTenantPaymentAmount;
  int? recordedTenantPaymentUserId;
  String? recordedTenantPaymentReference;

  _FakeTanteApi()
    : super(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'success': true, 'data': {}}), 200),
        ),
      );

  @override
  Future<List<Map<String, dynamic>>> getRentalProfiles(
    AuthSession session,
  ) async {
    return [
      {'id': 7, 'name': 'Tante Rentals', 'type': 'BUSINESS'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getProperties(
    int rentalProfileId,
    String token,
  ) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getLandlordLeases(
    int rentalProfileId,
    String token,
  ) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getLeaseDetails(
    int leaseId,
    String token,
  ) async {
    return {
      'id': leaseId,
      'referenceNumber': 'LEASE-$leaseId',
      'status': leaseStatus,
      'unitId': assignedUnitId,
      'startDate': updatedLeaseStartDate ?? '2026-01-01',
      'endDate': updatedLeaseEndDate ?? '2026-12-31',
      'rent': {'amount': 850000, 'currency': 'TZS', 'frequency': 'MONTHLY'},
      'fullLeasePaymentRequired': false,
      'leaseTerms': 'Standard terms',
      'tenant': {
        'firstName': 'Jordan',
        'lastName': 'Smith',
        'email': 'jordan@example.com',
        'phoneNumber': '+255712345678',
      },
      'invitations': [],
    };
  }

  @override
  Future<List<LeaseUnitOption>> getAvailableLeaseUnits(
    int rentalProfileId,
    String token,
  ) async {
    return const [
      LeaseUnitOption(
        id: 42,
        unitNumber: 'A2',
        propertyName: 'Green Court',
        buildingName: 'Block A',
        type: 'FLAT',
        status: 'AVAILABLE',
        rentAmount: 850000,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> assignLeaseUnit({
    required int leaseId,
    required int unitId,
    required String token,
  }) async {
    assignedUnitId = unitId;
    return getLeaseDetails(leaseId, token);
  }

  @override
  Future<Map<String, dynamic>> updateLeaseDates({
    required int leaseId,
    required String startDate,
    required String endDate,
    required String token,
  }) async {
    updatedLeaseStartDate = startDate;
    updatedLeaseEndDate = endDate;
    return getLeaseDetails(leaseId, token);
  }

  @override
  Future<Map<String, dynamic>> getLeaseRentSummary(
    int leaseId,
    String token,
  ) async {
    paymentSummaryRequests++;
    return {
      'totalExpectedAmount': 850000,
      'totalPaidAmount': 0,
      'totalOutstandingAmount': 850000,
      'paymentBlocks': paymentBlocks,
    };
  }

  @override
  Future<String> recordLeasePayment({
    required int rentalProfileId,
    required int paymentBlockId,
    required double amount,
    required String currency,
    required int payerUserId,
    required String method,
    required String reference,
    required String token,
    String? note,
  }) async {
    recordedPaymentBlockId = paymentBlockId;
    recordedPaymentAmount = amount;
    recordedPaymentUserId = payerUserId;
    recordedPaymentReference = reference;
    return 'Payment recorded successfully';
  }

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
  Future<RentalUnitDetails> getUnitDetails(int unitId, {String? token}) async {
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
    return tenantLeases;
  }

  @override
  Future<List<Map<String, dynamic>>> getTenantInvitations(
    String phoneNumber,
    String token,
  ) async {
    return tenantInvitations;
  }

  @override
  Future<Map<String, dynamic>> getTenantInvitation(
    String invitationToken,
    String token,
  ) async {
    return {
      'id': 8,
      'leaseId': 15,
      'invitationToken': invitationToken,
      'status': 'PENDING',
    };
  }

  @override
  Future<void> acceptTenantLeaseInvitation({
    required String invitationToken,
    required int userId,
    required String token,
  }) async {
    acceptedInvitationToken = invitationToken;
  }

  @override
  Future<List<Map<String, dynamic>>> getTenantViewingBookings(
    int requesterUserId,
    String token,
  ) async {
    return tenantViewingBookings;
  }

  @override
  Future<String> recordTenantLeasePayment({
    required int tenantId,
    required int paymentBlockId,
    required double amount,
    required String currency,
    required int payerUserId,
    required String method,
    required String token,
    String? reference,
    String? note,
  }) async {
    recordedTenantPaymentBlockId = paymentBlockId;
    recordedTenantPaymentAmount = amount;
    recordedTenantPaymentUserId = payerUserId;
    recordedTenantPaymentReference = reference;
    return 'Payment recorded successfully';
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
  Future<Map<String, dynamic>> getPropertyDetails(
    int propertyId,
    String token,
  ) async {
    propertyDetailsRequests++;
    if (failPropertyDetailsOnce && propertyDetailsRequests == 1) {
      throw const TanteApiException('Temporary property details failure.');
    }
    return {
      'id': propertyId,
      'name': 'Green Court',
      'type': 'COMPOUND',
      'description':
          '<p>Green <strong>living</strong></p><script>unsafe</script>',
      'buildings': [
        {
          'id': 8,
          'name': 'Block A',
          'number': 1,
          'numberOfFloors': 3,
          'units': [
            {
              'id': 12,
              'unitNumber': 'A1',
              'numberOfBedrooms': 2,
              'numberOfBathrooms': 1,
              'rentAmount': 850000,
              'type': 'FLAT',
              'status': 'AVAILABLE',
              'isListed': false,
            },
          ],
        },
      ],
    };
  }

  @override
  Future<bool> advertiseUnit({
    required int unitId,
    required String token,
  }) async {
    updatedUnitId = unitId;
    updatedListingStatus = true;
    return true;
  }

  @override
  Future<Map<String, dynamic>> createUnit({
    required int buildingId,
    required int rentalProfileId,
    required String token,
    required String unitNumber,
    required int numberOfBedrooms,
    required int numberOfBathrooms,
    required int numberParkingSpots,
    required double rentAmount,
    required String type,
    int? roomSize,
    String? sizeUnit,
  }) async {
    createdBuildingId = buildingId;
    createdRentalProfileId = rentalProfileId;
    createdUnitNumber = unitNumber;
    createdUnitRent = rentAmount;
    return {
      'id': 13,
      'unitNumber': unitNumber,
      'numberOfBedrooms': numberOfBedrooms,
      'numberOfBathrooms': numberOfBathrooms,
      'numberParkingSpots': numberParkingSpots,
      'rentAmount': rentAmount,
      'type': type,
      'status': 'AVAILABLE',
      'isListed': false,
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

  @override
  Future<List<Map<String, dynamic>>> getViewingBookings(
    int rentalProfileId,
    String token,
  ) async {
    final failure = viewingBookingsFailure;
    if (failure != null) {
      viewingBookingsFailure = null;
      throw TanteApiException(failure);
    }
    return viewingBookings;
  }

  Future<Map<String, dynamic>> _updateFakeViewingBooking(
    int bookingId,
    String action,
    String status,
  ) async {
    updatedViewingAction = action;
    final booking = viewingBookings.singleWhere(
      (item) => item['id'] == bookingId,
    );
    final updated = {...booking, 'status': status};
    viewingBookings = viewingBookings
        .map((item) => item['id'] == bookingId ? updated : item)
        .toList();
    return updated;
  }

  @override
  Future<Map<String, dynamic>> approveViewingBooking({
    required int bookingId,
    required String token,
  }) => _updateFakeViewingBooking(bookingId, 'approve', 'CONFIRMED');

  @override
  Future<Map<String, dynamic>> rejectViewingBooking({
    required int bookingId,
    required String token,
  }) => _updateFakeViewingBooking(bookingId, 'reject', 'REJECTED');

  @override
  Future<Map<String, dynamic>> cancelViewingBooking({
    required int bookingId,
    required String token,
  }) => _updateFakeViewingBooking(bookingId, 'cancel', 'CANCELLED');

  @override
  Future<Map<String, dynamic>> recordViewingOutcome({
    required int bookingId,
    required String outcome,
    required String token,
    String? notes,
  }) async {
    updatedViewingAction = 'outcome';
    recordedViewingOutcome = outcome;
    recordedViewingNotes = notes;
    final booking = viewingBookings.singleWhere(
      (item) => item['id'] == bookingId,
    );
    final updated = {
      ...booking,
      'status': 'CLOSED',
      'outcome': {
        'id': 1,
        'bookingId': bookingId,
        'type': outcome,
        'notes': notes,
        'recordedAt': '2030-02-03T16:10:00',
      },
    };
    viewingBookings = viewingBookings
        .map((item) => item['id'] == bookingId ? updated : item)
        .toList();
    return updated;
  }
}
