import 'dart:convert';

import 'package:http/http.dart' as http;

const authApiBaseUrl = String.fromEnvironment(
  'AUTH_API_BASE_URL',
  defaultValue: 'http://localhost:8081/auth-manager',
);
const rentApiBaseUrl = String.fromEnvironment(
  'RENT_API_BASE_URL',
  defaultValue: 'http://localhost:8083/rent-manager',
);
const propertyApiBaseUrl = String.fromEnvironment(
  'PROPERTY_API_BASE_URL',
  defaultValue: 'http://localhost:8082/property-manager',
);

class TanteApiException implements Exception {
  const TanteApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TanteUserProfileMissingException extends TanteApiException {
  const TanteUserProfileMissingException({
    required this.phoneNumber,
    required this.token,
    required this.role,
  }) : super('Complete your user profile to continue.');

  final String phoneNumber;
  final String token;
  final String role;
}

class AuthSession {
  const AuthSession({
    required this.phoneNumber,
    required this.token,
    required this.userId,
    required this.role,
    this.email,
    this.memberships = const [],
  });

  final String phoneNumber;
  final String token;
  final int userId;
  final String role;
  final String? email;
  final List<Map<String, dynamic>> memberships;
}

class RentalListing {
  const RentalListing({
    required this.id,
    required this.unitNumber,
    required this.bedrooms,
    required this.bathrooms,
    required this.rentAmount,
    required this.type,
    required this.status,
    required this.propertyName,
    required this.streetName,
    required this.city,
    required this.region,
  });

  final int id;
  final String unitNumber;
  final int bedrooms;
  final int bathrooms;
  final double rentAmount;
  final String type;
  final String status;
  final String propertyName;
  final String streetName;
  final String city;
  final String region;

  factory RentalListing.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final address = location is Map ? location['address'] : null;
    final addressMap = address is Map ? address : const <String, dynamic>{};
    return RentalListing(
      id: _requiredInt(json, 'id'),
      unitNumber: _requiredString(json, 'unitNumber'),
      bedrooms: _requiredInt(json, 'numberOfBedrooms'),
      bathrooms: _requiredInt(json, 'numberOfBathrooms'),
      rentAmount: _requiredDouble(json, 'rentAmount'),
      type: _requiredString(json, 'type'),
      status: json['status']?.toString() ?? 'AVAILABLE',
      propertyName: _requiredString(json, 'propertyName'),
      streetName: addressMap['streetName']?.toString() ?? '',
      city: addressMap['city']?.toString() ?? '',
      region: addressMap['region']?.toString() ?? '',
    );
  }
}

class RentalListingsPage {
  const RentalListingsPage({required this.items, required this.totalElements});

  final List<RentalListing> items;
  final int totalElements;
}

class RentalUnitImage {
  const RentalUnitImage({required this.id, required this.url});

  final int id;
  final String url;

  factory RentalUnitImage.fromJson(Map<String, dynamic> json) {
    return RentalUnitImage(
      id: _requiredInt(json, 'id'),
      url: _requiredString(json, 'url'),
    );
  }
}

class RentalUnitDetails {
  const RentalUnitDetails({
    required this.id,
    required this.unitNumber,
    required this.rentalProfileId,
    required this.bedrooms,
    required this.bathrooms,
    required this.parkingSpaces,
    required this.rentAmount,
    required this.type,
    required this.status,
    required this.roomSize,
    required this.sizeUnit,
    required this.floorNumber,
    required this.buildingNumber,
    required this.buildingName,
    required this.propertyName,
    required this.propertyDescription,
    required this.address,
    required this.images,
  });

  final int id;
  final String unitNumber;
  final int rentalProfileId;
  final int bedrooms;
  final int bathrooms;
  final int parkingSpaces;
  final double rentAmount;
  final String type;
  final String? status;
  final num? roomSize;
  final String? sizeUnit;
  final int floorNumber;
  final int buildingNumber;
  final String buildingName;
  final String propertyName;
  final String? propertyDescription;
  final List<String> address;
  final List<RentalUnitImage> images;

  factory RentalUnitDetails.fromJson(Map<String, dynamic> json) {
    final building = _requiredMap(json, 'building');
    final property = _requiredMap(building, 'property');
    final location = _requiredMap(property, 'location');
    final address = _requiredMap(location, 'address');
    final imageValues = json['images'];
    if (imageValues != null && imageValues is! List) {
      throw const TanteApiException(
        'The property service returned invalid unit images.',
      );
    }

    return RentalUnitDetails(
      id: _requiredInt(json, 'id'),
      unitNumber: _requiredString(json, 'unitNumber'),
      rentalProfileId: _requiredInt(json, 'rentalProfileId'),
      bedrooms: _requiredInt(json, 'numberOfBedrooms'),
      bathrooms: _requiredInt(json, 'numberOfBathrooms'),
      parkingSpaces: _requiredInt(json, 'numberParkingSpots'),
      rentAmount: _requiredDouble(json, 'rentAmount'),
      type: _requiredString(json, 'type'),
      status: json['status']?.toString(),
      roomSize: json['roomSize'] is num ? json['roomSize'] as num : null,
      sizeUnit: json['sizeUnit']?.toString(),
      floorNumber: _requiredInt(json, 'floorNumber'),
      buildingNumber: _requiredInt(building, 'number'),
      buildingName: building['name']?.toString() ?? '',
      propertyName: _requiredString(property, 'name'),
      propertyDescription: property['description']?.toString(),
      address: [
        address['houseNumber']?.toString(),
        address['streetName']?.toString(),
        address['ward']?.toString(),
        address['city']?.toString(),
        address['region']?.toString(),
        address['country']?.toString(),
      ].whereType<String>().where((part) => part.trim().isNotEmpty).toList(),
      images: (imageValues as List? ?? const []).map((image) {
        if (image is! Map) {
          throw const TanteApiException(
            'The property service returned an invalid unit image.',
          );
        }
        return RentalUnitImage.fromJson(Map<String, dynamic>.from(image));
      }).toList(),
    );
  }
}

class LeaseUnitOption {
  const LeaseUnitOption({
    required this.id,
    required this.unitNumber,
    required this.propertyName,
    required this.buildingName,
    required this.type,
    required this.status,
    required this.rentAmount,
  });

  final int id;
  final String unitNumber;
  final String propertyName;
  final String buildingName;
  final String type;
  final String? status;
  final double rentAmount;
}

class TanteApi {
  TanteApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<RentalListingsPage> getListedUnits({
    required int page,
    required String location,
    required String type,
    required int minBedrooms,
    required String minRent,
    required String maxRent,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'size': '12',
      'sortBy': 'rentAmount',
      'direction': 'asc',
      'isListed': 'true',
      'status': 'AVAILABLE',
      if (location.trim().isNotEmpty) 'location': location.trim(),
      if (type.isNotEmpty) 'type': type,
      if (minBedrooms > 0) 'minBedrooms': '$minBedrooms',
      if (minRent.isNotEmpty) 'minRent': minRent,
      if (maxRent.isNotEmpty) 'maxRent': maxRent,
    };
    final uri = Uri.parse(
      '$propertyApiBaseUrl/v1/units',
    ).replace(queryParameters: queryParameters);
    final result = await _request('GET', uri.toString());
    if (result is! Map || result['items'] is! List) {
      throw const TanteApiException(
        'The property service returned an invalid listings response.',
      );
    }

    final rawItems = result['items'] as List;
    final items = rawItems.map((item) {
      if (item is! Map) {
        throw const TanteApiException(
          'The property service returned an invalid listing.',
        );
      }
      return RentalListing.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    return RentalListingsPage(
      items: items,
      totalElements: _requiredInt(
        Map<String, dynamic>.from(result),
        'totalElements',
      ),
    );
  }

  Future<RentalUnitDetails> getUnitDetails(int unitId, {String? token}) async {
    final result = await _request(
      'GET',
      '$propertyApiBaseUrl/v1/units/$unitId',
      token: token,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The property service returned an invalid unit response.',
      );
    }
    return RentalUnitDetails.fromJson(Map<String, dynamic>.from(result));
  }

  Future<Map<String, dynamic>> getPropertyDetails(
    int propertyId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$propertyApiBaseUrl/v1/properties/$propertyId',
      token: token,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The property service returned an invalid property response.',
      );
    }
    final property = Map<String, dynamic>.from(result);
    final buildings = property['buildings'];
    if (buildings != null) {
      if (buildings is! List || buildings.any((building) => building is! Map)) {
        throw const TanteApiException(
          'The property service returned invalid building details.',
        );
      }
      for (final building in buildings) {
        final units = (building as Map)['units'];
        if (units != null &&
            (units is! List || units.any((unit) => unit is! Map))) {
          throw const TanteApiException(
            'The property service returned invalid unit details.',
          );
        }
      }
    }
    return property;
  }

  Future<bool> advertiseUnit({
    required int unitId,
    required String token,
  }) async {
    final result = await _request(
      'PATCH',
      '$propertyApiBaseUrl/v1/units/$unitId/listing/status',
      token: token,
      body: {'isListed': true},
    );
    if (result is! bool) {
      throw const TanteApiException(
        'The property service returned an invalid unit listing status.',
      );
    }
    return result;
  }

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
    final result = await _request(
      'POST',
      '$propertyApiBaseUrl/v1/units/building/$buildingId',
      token: token,
      body: {
        'unitNumber': unitNumber.trim(),
        'rentalProfileId': rentalProfileId,
        'numberOfBedrooms': numberOfBedrooms,
        'numberOfBathrooms': numberOfBathrooms,
        'numberParkingSpots': numberParkingSpots,
        'rentAmount': rentAmount,
        'type': type,
        'status': 'AVAILABLE',
        'roomSize': ?roomSize,
        'sizeUnit': ?_nonEmpty(sizeUnit),
      },
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The property service returned an invalid created unit.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<AuthSession> signIn({
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    final auth = await _request(
      'POST',
      '$authApiBaseUrl/v1/auth',
      body: {'phoneNumber': phoneNumber.trim(), 'passWord': password},
      authenticated: false,
    );
    final token = _string(auth['jwtToken']);
    if (token.isEmpty) {
      throw const TanteApiException(
        'The authentication service did not return a token.',
      );
    }

    late final dynamic user;
    try {
      user = await _request(
        'GET',
        '$authApiBaseUrl/v1/users/${Uri.encodeComponent(phoneNumber.trim())}',
        token: token,
      );
    } on TanteApiException catch (error) {
      if (error.statusCode == 404) {
        throw TanteUserProfileMissingException(
          phoneNumber: phoneNumber.trim(),
          token: token,
          role: role,
        );
      }
      rethrow;
    }
    final userId = _int(user['id']);
    if (userId == null) {
      throw const TanteApiException(
        'Your account profile is missing a user ID.',
      );
    }
    return AuthSession(
      phoneNumber: phoneNumber.trim(),
      token: token,
      userId: userId,
      role: role,
      email: _string(user['email']).isEmpty ? null : _string(user['email']),
      memberships: _maps(user['memberships']),
    );
  }

  Future<Map<String, dynamic>> registerAccount({
    required String phoneNumber,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '$authApiBaseUrl/v1/auth/account',
      body: {'phoneNumber': phoneNumber.trim(), 'passWord': password},
      authenticated: false,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The authentication service returned an invalid account.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<AuthSession> createUserProfile({
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String token,
    required String role,
  }) async {
    final result = await _request(
      'POST',
      '$authApiBaseUrl/v1/users',
      token: token,
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phoneNumber.trim(),
      },
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The authentication service returned an invalid user profile.',
      );
    }
    final user = Map<String, dynamic>.from(result);
    final userId = _int(user['id']);
    if (userId == null) {
      throw const TanteApiException(
        'The authentication service returned a profile without a user ID.',
      );
    }
    return AuthSession(
      phoneNumber: phoneNumber.trim(),
      token: token,
      userId: userId,
      role: role,
      email: _string(user['email']).isEmpty ? null : _string(user['email']),
      memberships: _maps(user['memberships']),
    );
  }

  Future<List<Map<String, dynamic>>> getRentalProfiles(
    AuthSession session,
  ) async {
    // Organization ID 0 is used by the web app to retrieve individual profiles.
    final organizationIds = <int>{0};
    for (final membership in session.memberships) {
      final organizationId = _int(membership['organizationId']);
      if (organizationId != null && organizationId > 0) {
        organizationIds.add(organizationId);
      }
    }

    final profilesById = <String, Map<String, dynamic>>{};
    for (final organizationId in organizationIds) {
      try {
        final result = await _request(
          'GET',
          '$rentApiBaseUrl/v1/rentalprofiles/${session.userId}/$organizationId',
          token: session.token,
        );
        for (final profile in _maps(result)) {
          final id = _string(profile['id']);
          if (id.isNotEmpty) profilesById[id] = profile;
        }
      } on TanteApiException {
        // A membership may not have a rental profile. Continue to load the others.
      }
    }
    return profilesById.values.toList();
  }

  Future<Map<String, dynamic>> getRentalProfileDetails(
    int rentalProfileId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/rentalprofiles/$rentalProfileId',
      token: token,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned an invalid agency profile.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> createViewingBooking({
    required int rentalProfileId,
    required int unitId,
    required DateTime startTime,
    required int requesterUserAccountId,
    required double serviceFee,
    required String token,
    String? notes,
  }) async {
    final endTime = startTime.add(const Duration(minutes: 100));
    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/viewings/bookings',
      token: token,
      body: {
        'rentalProfileId': rentalProfileId,
        'unitId': unitId,
        'startTime': _formatLocalDateTime(startTime),
        'endTime': _formatLocalDateTime(endTime),
        'requesterUserAccountId': requesterUserAccountId,
        'serviceFee': serviceFee,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned an invalid viewing booking.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> getViewingBookings(
    int rentalProfileId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/viewings/bookings/by-rental-profile/$rentalProfileId',
      token: token,
    );
    if (result is! List || result.any((booking) => booking is! Map)) {
      throw const TanteApiException(
        'The rent service returned invalid viewing bookings.',
      );
    }
    return result.map((booking) {
      final parsed = Map<String, dynamic>.from(booking as Map);
      _validateViewingBooking(parsed);
      return parsed;
    }).toList();
  }

  Future<Map<String, dynamic>> approveViewingBooking({
    required int bookingId,
    required String token,
  }) {
    return _updateViewingBooking(
      bookingId: bookingId,
      action: 'approve',
      token: token,
    );
  }

  Future<Map<String, dynamic>> rejectViewingBooking({
    required int bookingId,
    required String token,
  }) {
    return _updateViewingBooking(
      bookingId: bookingId,
      action: 'reject',
      token: token,
    );
  }

  Future<Map<String, dynamic>> cancelViewingBooking({
    required int bookingId,
    required String token,
  }) {
    return _updateViewingBooking(
      bookingId: bookingId,
      action: 'cancel',
      token: token,
    );
  }

  Future<Map<String, dynamic>> recordViewingOutcome({
    required int bookingId,
    required String outcome,
    required String token,
    String? notes,
  }) {
    return _updateViewingBooking(
      bookingId: bookingId,
      action: 'outcome',
      token: token,
      body: {
        'outcome': outcome,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> _updateViewingBooking({
    required int bookingId,
    required String action,
    required String token,
    Object? body,
  }) async {
    final result = await _request(
      'PATCH',
      '$rentApiBaseUrl/v1/viewings/bookings/$bookingId/$action',
      token: token,
      body: body,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned an invalid updated viewing booking.',
      );
    }
    final booking = Map<String, dynamic>.from(result);
    _validateViewingBooking(booking);
    return booking;
  }

  Future<Map<String, dynamic>> createRentalProfile({
    required AuthSession session,
    required String name,
    required String phoneNumber,
    required String type,
    required double viewingServiceFee,
    String? email,
    int? organizationId,
  }) async {
    if (!viewingServiceFee.isFinite || viewingServiceFee < 0) {
      throw const TanteApiException(
        'Enter a valid non-negative viewing service fee.',
      );
    }
    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/rentalprofiles',
      token: session.token,
      body: {
        'name': name.trim(),
        'phoneNumber': phoneNumber.trim(),
        'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
        'type': type,
        'viewingServiceFee': viewingServiceFee,
        'userId': session.userId,
        'organizationId': ?organizationId,
      },
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const TanteApiException(
      'The server did not return the new rental profile.',
    );
  }

  Future<Map<String, dynamic>> createProperty({
    required int rentalProfileId,
    required int createdByUserId,
    required String token,
    required String name,
    required String type,
    required int numberOfBuildings,
    required Map<String, dynamic> address,
    String? description,
    String? developmentStatus,
    double? landSize,
    String? landSizeUnit,
    String? locationName,
    double latitude = 0,
    double longitude = 0,
  }) async {
    final result = await _request(
      'POST',
      '$propertyApiBaseUrl/v1/properties/rental-profile/$rentalProfileId',
      token: token,
      body: {
        'createdByUserId': createdByUserId,
        'name': name.trim(),
        'type': type,
        'numberOfBuildings': numberOfBuildings,
        'location': {
          'name': ?_nonEmpty(locationName),
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
        'description': ?_nonEmpty(description),
        'developmentStatus': ?developmentStatus,
        'landSize': ?landSize,
        'landSizeUnit': ?_nonEmpty(landSizeUnit),
      },
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The property service returned an invalid created property.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> getProperties(
    int rentalProfileId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$propertyApiBaseUrl/v1/properties/rental-profile/$rentalProfileId',
      token: token,
    );
    return _maps(result);
  }

  Future<List<LeaseUnitOption>> getAvailableLeaseUnits(
    int rentalProfileId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$propertyApiBaseUrl/v1/properties/rental-profile/$rentalProfileId',
      token: token,
    );
    if (result is! List || result.any((property) => property is! Map)) {
      throw const TanteApiException(
        'The property service returned an invalid property list.',
      );
    }

    final availableUnits = <LeaseUnitOption>[];
    for (final propertyValue in result) {
      final property = Map<String, dynamic>.from(propertyValue as Map);
      final buildings = property['buildings'];
      if (buildings != null &&
          (buildings is! List ||
              buildings.any((building) => building is! Map))) {
        throw const TanteApiException(
          'The property service returned invalid building details.',
        );
      }
      for (final buildingValue in buildings as List? ?? const []) {
        final building = Map<String, dynamic>.from(buildingValue as Map);
        final units = building['units'];
        if (units != null &&
            (units is! List || units.any((unit) => unit is! Map))) {
          throw const TanteApiException(
            'The property service returned invalid unit details.',
          );
        }
        for (final unitValue in units as List? ?? const []) {
          final unit = Map<String, dynamic>.from(unitValue as Map);
          final status = unit['status']?.toString();
          if (status != null && status.toUpperCase() != 'AVAILABLE') continue;
          availableUnits.add(
            LeaseUnitOption(
              id: _requiredInt(unit, 'id'),
              unitNumber: _requiredString(unit, 'unitNumber'),
              propertyName: _requiredString(property, 'name'),
              buildingName:
                  building['name']?.toString() ??
                  building['code']?.toString() ??
                  'Building',
              type: unit['type']?.toString() ?? 'Unit',
              status: status,
              rentAmount: _requiredDouble(unit, 'rentAmount'),
            ),
          );
        }
      }
    }
    return availableUnits;
  }

  Future<Map<String, dynamic>> assignLeaseUnit({
    required int leaseId,
    required int unitId,
    required String token,
  }) {
    return _updateLease(
      leaseId: leaseId,
      endpoint: 'unit',
      token: token,
      body: {'unitId': unitId},
    );
  }

  Future<List<Map<String, dynamic>>> getLandlordLeases(
    int rentalProfileId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/leases/rental-profile/$rentalProfileId',
      token: token,
    );
    return _maps(result);
  }

  Future<Map<String, dynamic>> createLandlordLease({
    required int rentalProfileId,
    required String tenantFirstName,
    required String tenantLastName,
    required String tenantPhoneNumber,
    required String startDate,
    required String endDate,
    required double rentAmount,
    required String rentFrequency,
    required bool fullLeasePaymentRequired,
    required String token,
    int? unitId,
    String leaseTerms = '',
  }) async {
    if (rentalProfileId <= 0 ||
        tenantFirstName.trim().isEmpty ||
        tenantLastName.trim().isEmpty ||
        tenantPhoneNumber.trim().isEmpty ||
        rentAmount < 0 ||
        !rentAmount.isFinite) {
      throw const TanteApiException('Enter all required lease details.');
    }
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null || !start.isBefore(end)) {
      throw const TanteApiException(
        'The lease end date must be after the start date.',
      );
    }
    const frequencies = {'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'};
    if (!frequencies.contains(rentFrequency)) {
      throw const TanteApiException('Select a valid rent frequency.');
    }

    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/leases/landlord',
      token: token,
      body: {
        'rentalProfileId': rentalProfileId,
        'unitId': ?unitId,
        'tenantFirstName': tenantFirstName.trim(),
        'tenantLastName': tenantLastName.trim(),
        'tenantPhoneNumber': tenantPhoneNumber.trim(),
        'startDate': startDate,
        'endDate': endDate,
        'rent': {
          'id': 0,
          'amount': rentAmount,
          'currency': 'TZS',
          'frequency': rentFrequency,
        },
        'leaseTerms': leaseTerms,
        'fullLeasePaymentRequired': fullLeasePaymentRequired,
      },
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned an invalid created lease.',
      );
    }
    final lease = Map<String, dynamic>.from(result);
    _validateLeaseDetails(lease);
    return lease;
  }

  Future<Map<String, dynamic>> getLeaseDetails(
    int leaseId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/leases/$leaseId',
      token: token,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned invalid lease details.',
      );
    }
    final lease = Map<String, dynamic>.from(result);
    _validateLeaseDetails(lease);
    return lease;
  }

  Future<Map<String, dynamic>> updateLeaseDates({
    required int leaseId,
    required String startDate,
    required String endDate,
    required String token,
  }) {
    return _updateLease(
      leaseId: leaseId,
      endpoint: 'dates',
      token: token,
      body: {'startDate': startDate, 'endDate': endDate},
    );
  }

  Future<Map<String, dynamic>> updateLeaseRent({
    required int leaseId,
    required double amount,
    required String currency,
    required String frequency,
    required bool fullLeasePaymentRequired,
    required String token,
  }) {
    return _updateLease(
      leaseId: leaseId,
      endpoint: 'rent',
      token: token,
      body: {
        'rent': {
          'amount': amount,
          'currency': currency,
          'frequency': frequency,
        },
        'fullLeasePaymentRequired': fullLeasePaymentRequired,
      },
    );
  }

  Future<Map<String, dynamic>> updateLeaseTerms({
    required int leaseId,
    required String leaseTerms,
    required String token,
  }) {
    return _updateLease(
      leaseId: leaseId,
      endpoint: 'terms',
      token: token,
      body: {'leaseTerms': leaseTerms},
    );
  }

  Future<Map<String, dynamic>> _updateLease({
    required int leaseId,
    required String endpoint,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final result = await _request(
      'PATCH',
      '$rentApiBaseUrl/v1/leases/$leaseId/$endpoint',
      token: token,
      body: body,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned invalid updated lease details.',
      );
    }
    final lease = Map<String, dynamic>.from(result);
    _validateLeaseDetails(lease);
    return lease;
  }

  Future<Map<String, dynamic>> getLeaseRentSummary(
    int leaseId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/leases/rent/summary/$leaseId',
      token: token,
    );
    if (result is! Map ||
        !_isNumber(result['totalExpectedAmount']) ||
        !_isNumber(result['totalPaidAmount']) ||
        !_isNumber(result['totalOutstandingAmount']) ||
        result['paymentBlocks'] is! List ||
        (result['paymentBlocks'] as List).any((block) => block is! Map)) {
      throw const TanteApiException(
        'The rent service returned an invalid lease payment summary.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

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
    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/payment-blocks/tenant/$tenantId/record-payment',
      token: token,
      body: {
        'paymentBlockId': paymentBlockId,
        'amount': amount,
        'currency': currency,
        'payerUserId': payerUserId,
        'method': method,
        'reference': reference?.trim() ?? '',
        'note': note?.trim() ?? '',
      },
    );
    if (result is! String || result.trim().isEmpty) {
      throw const TanteApiException(
        'The rent service returned an invalid payment confirmation.',
      );
    }
    return result;
  }

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
    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/payment-blocks/rental-profile/$rentalProfileId/record-payment',
      token: token,
      body: {
        'paymentBlockId': paymentBlockId,
        'amount': amount,
        'currency': currency,
        'payerUserId': payerUserId,
        'method': method,
        'reference': reference.trim(),
        'note': note?.trim() ?? '',
      },
    );
    if (result is! String || result.trim().isEmpty) {
      throw const TanteApiException(
        'The rent service returned an invalid payment confirmation.',
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> getTenantDetails(
    int userId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/tenants?userId=$userId',
      token: token,
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const TanteApiException(
      'The rent service returned an invalid tenant profile.',
    );
  }

  Future<List<Map<String, dynamic>>> getTenantLeases(
    int tenantId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/leases/tenant/$tenantId',
      token: token,
    );
    if (result is! List || result.any((lease) => lease is! Map)) {
      throw const TanteApiException(
        'The rent service returned invalid tenant leases.',
      );
    }
    return result
        .map((lease) => Map<String, dynamic>.from(lease as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getTenantInvitations(
    String phoneNumber,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/lease-invitations/phone/${Uri.encodeComponent(phoneNumber)}',
      token: token,
    );
    if (result is! List || result.any((invitation) => invitation is! Map)) {
      throw const TanteApiException(
        'The rent service returned invalid lease invitations.',
      );
    }
    return result.map((invitation) {
      final parsed = Map<String, dynamic>.from(invitation as Map);
      if (!_isNumber(parsed['id']) ||
          !_isNumber(parsed['leaseId']) ||
          parsed['invitationToken'] is! String ||
          (parsed['invitationToken'] as String).trim().isEmpty ||
          parsed['status'] is! String ||
          (parsed['status'] as String).trim().isEmpty) {
        throw const TanteApiException(
          'The rent service returned an invalid lease invitation.',
        );
      }
      return parsed;
    }).toList();
  }

  Future<Map<String, dynamic>> getTenantInvitation(
    String invitationToken,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/lease-invitations/${Uri.encodeComponent(invitationToken)}',
      token: token,
    );
    if (result is! Map) {
      throw const TanteApiException(
        'The rent service returned invalid invitation details.',
      );
    }
    final invitation = Map<String, dynamic>.from(result);
    if (!_isNumber(invitation['id']) ||
        !_isNumber(invitation['leaseId']) ||
        invitation['invitationToken'] is! String ||
        invitation['status'] is! String) {
      throw const TanteApiException(
        'The rent service returned an invalid lease invitation.',
      );
    }
    return invitation;
  }

  Future<void> acceptTenantLeaseInvitation({
    required String invitationToken,
    required int userId,
    required String token,
  }) async {
    await _request(
      'POST',
      '$rentApiBaseUrl/v1/lease-invitations/${Uri.encodeComponent(invitationToken)}/tenant/accept?userId=$userId',
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> getTenantViewingBookings(
    int requesterUserId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/viewings/bookings/by-requester/$requesterUserId',
      token: token,
    );
    if (result is! List || result.any((booking) => booking is! Map)) {
      throw const TanteApiException(
        'The rent service returned invalid viewing bookings.',
      );
    }
    return result.map((booking) {
      final parsed = Map<String, dynamic>.from(booking as Map);
      _validateViewingBooking(parsed);
      return parsed;
    }).toList();
  }

  Future<dynamic> _request(
    String method,
    String url, {
    Object? body,
    String? token,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final uri = Uri.parse(url);
      final response = switch (method) {
        'POST' =>
          await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20)),
        'PATCH' =>
          await _client
              .patch(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20)),
        'GET' =>
          await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20)),
        _ => throw const TanteApiException('Unsupported API request.'),
      };
      dynamic decoded;
      try {
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
      } on FormatException {
        throw const TanteApiException(
          'The server returned an unreadable response.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map
            ? _apiErrorMessage(Map<String, dynamic>.from(decoded))
            : '';
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw TanteApiException(
            message.isEmpty || message == 'UNAUTHORIZED'
                ? 'Sign-in failed. Check your phone number and password.'
                : message,
            statusCode: response.statusCode,
          );
        }
        throw TanteApiException(
          message.isEmpty
              ? 'Request failed (${response.statusCode}).'
              : message,
          statusCode: response.statusCode,
        );
      }
      if (decoded is Map &&
          decoded.containsKey('success') &&
          decoded['success'] == false) {
        final message = _apiErrorMessage(Map<String, dynamic>.from(decoded));
        throw TanteApiException(
          message.isEmpty ? 'The request could not be completed.' : message,
        );
      }
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    } on TanteApiException {
      rethrow;
    } catch (_) {
      throw const TanteApiException(
        'Could not connect to Tante. Check your connection and try again.',
      );
    }
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _string(dynamic value) => value?.toString() ?? '';

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _apiErrorMessage(Map<String, dynamic> response) {
    final message = _string(response['message']).trim();
    final details = _formatErrorDetails(response['data']);
    if (details.isNotEmpty && _isMachineReadableError(message)) {
      return details;
    }
    if (message.isNotEmpty) return message;
    return details;
  }

  static bool _isMachineReadableError(String message) {
    return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(message);
  }

  static String _formatErrorDetails(Object? value) {
    if (value is String) return value.trim();
    if (value is List) {
      return value
          .map(_formatErrorDetails)
          .where((detail) => detail.isNotEmpty)
          .join('; ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) {
            final detail = _formatErrorDetails(entry.value);
            return detail.isEmpty ? '' : '${entry.key}: $detail';
          })
          .where((detail) => detail.isNotEmpty)
          .join('; ');
    }
    return '';
  }

  static int? _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_string(value));
}

void _validateViewingBooking(Map<String, dynamic> booking) {
  final requiredIntegerFields = [
    'id',
    'rentalProfileId',
    'unitId',
    'requesterUserId',
  ];
  final hasInvalidInteger = requiredIntegerFields.any((field) {
    final value = booking[field];
    return value is! num && int.tryParse(value?.toString() ?? '') == null;
  });
  final requiredStringFields = [
    'reference',
    'startTime',
    'endTime',
    'status',
    'paymentStatus',
  ];
  final hasInvalidString = requiredStringFields.any((field) {
    final value = booking[field];
    return value is! String || value.trim().isEmpty;
  });
  final fee = booking['serviceFee'];
  final outcome = booking['outcome'];
  if (hasInvalidInteger ||
      hasInvalidString ||
      (fee is! num && double.tryParse(fee?.toString() ?? '') == null) ||
      (outcome != null && outcome is! Map)) {
    throw const TanteApiException(
      'The rent service returned an invalid viewing booking.',
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw TanteApiException(
      'The property service returned an invalid $key value.',
    );
  }
  return parsed;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw TanteApiException(
      'The property service returned an invalid $key value.',
    );
  }
  return parsed;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw TanteApiException(
      'The property service returned an invalid $key value.',
    );
  }
  return value;
}

String _formatLocalDateTime(DateTime value) {
  String twoDigits(int component) => component.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}'
      'T${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw TanteApiException('The property service returned an invalid $key.');
  }
  return Map<String, dynamic>.from(value);
}

bool _isNumber(Object? value) =>
    value is num || double.tryParse(value?.toString() ?? '') != null;

void _validateLeaseDetails(Map<String, dynamic> lease) {
  final rent = lease['rent'];
  final invitations = lease['invitations'];
  final tenant = lease['tenant'];
  if (!_isNumber(lease['id']) ||
      lease['status'] is! String ||
      (lease['status'] as String).trim().isEmpty ||
      lease['startDate'] is! String ||
      (lease['startDate'] as String).trim().isEmpty ||
      lease['endDate'] is! String ||
      (lease['endDate'] as String).trim().isEmpty ||
      rent is! Map ||
      !_isNumber(rent['amount']) ||
      rent['currency'] is! String ||
      (rent['currency'] as String).trim().isEmpty ||
      rent['frequency'] is! String ||
      (rent['frequency'] as String).trim().isEmpty ||
      (tenant != null && tenant is! Map) ||
      (invitations != null &&
          (invitations is! List ||
              invitations.any((invitation) => invitation is! Map)))) {
    throw const TanteApiException(
      'The rent service returned invalid lease details.',
    );
  }
}
