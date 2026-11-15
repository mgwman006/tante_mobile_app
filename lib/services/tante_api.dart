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
  const TanteApiException(this.message);
  final String message;

  @override
  String toString() => message;
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

class TanteApi {
  TanteApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<RentalListingsPage> getListedUnits({
    required int page,
    required String city,
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
      if (city.trim().isNotEmpty) 'city': city.trim(),
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

    final user = await _request(
      'GET',
      '$authApiBaseUrl/v1/users/${Uri.encodeComponent(phoneNumber.trim())}',
      token: token,
    );
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

  Future<Map<String, dynamic>> createRentalProfile({
    required AuthSession session,
    required String name,
    required String phoneNumber,
    required String type,
    String? email,
    int? organizationId,
  }) async {
    final result = await _request(
      'POST',
      '$rentApiBaseUrl/v1/rentalprofiles',
      token: session.token,
      body: {
        'name': name.trim(),
        'phoneNumber': phoneNumber.trim(),
        'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
        'type': type,
        'userId': session.userId,
        'organizationId': ?organizationId,
      },
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const TanteApiException(
      'The server did not return the new rental profile.',
    );
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

  Future<Map<String, dynamic>> getTenantDetails(
    int userId,
    String token,
  ) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/tenants?userId=$userId',
      token: token,
    );
    return _maps(result).first;
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
    return _maps(result);
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
        final message = decoded is Map ? _string(decoded['message']) : '';
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw TanteApiException(
            message.isEmpty
                ? 'Sign-in failed. Check your phone number and password.'
                : message,
          );
        }
        throw TanteApiException(
          message.isEmpty
              ? 'Request failed (${response.statusCode}).'
              : message,
        );
      }
      if (decoded is Map &&
          decoded.containsKey('success') &&
          decoded['success'] == false) {
        throw TanteApiException(
          _string(decoded['message']).isEmpty
              ? 'The request could not be completed.'
              : _string(decoded['message']),
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

  static int? _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_string(value));
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
