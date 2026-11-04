import 'dart:convert';

import 'package:http/http.dart' as http;

const authApiBaseUrl = 'https://api.auth.tante.tz/auth-manager';
const rentApiBaseUrl = 'https://api.rent-manager.tante.tz/rent-manager';
const propertyApiBaseUrl = 'https://api.property-manager.tante.tz/property-manager';

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
  });

  final String phoneNumber;
  final String token;
  final int userId;
  final String role;
  final String? email;
}

class TanteApi {
  TanteApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

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
      throw const TanteApiException('The authentication service did not return a token.');
    }

    final user = await _request(
      'GET',
      '$authApiBaseUrl/v1/users/${Uri.encodeComponent(phoneNumber.trim())}',
      token: token,
    );
    final userId = _int(user['id']);
    if (userId == null) {
      throw const TanteApiException('Your account profile is missing a user ID.');
    }
    return AuthSession(
      phoneNumber: phoneNumber.trim(),
      token: token,
      userId: userId,
      role: role,
      email: _string(user['email']).isEmpty ? null : _string(user['email']),
    );
  }

  Future<List<Map<String, dynamic>>> getRentalProfiles(AuthSession session) async {
    final user = await _request(
      'GET',
      '$authApiBaseUrl/v1/users/${Uri.encodeComponent(session.phoneNumber)}',
      token: session.token,
    );
    final memberships = _maps(user['memberships']);
    final profiles = <Map<String, dynamic>>[];
    for (final membership in memberships) {
      final organizationId = _int(membership['organizationId']);
      if (organizationId == null) continue;
      try {
        final result = await _request(
          'GET',
          '$rentApiBaseUrl/v1/rentalprofiles/${session.userId}/$organizationId',
          token: session.token,
        );
        profiles.addAll(_maps(result));
      } on TanteApiException {
        // A user may have memberships that are not rental-profile memberships.
      }
    }
    return profiles;
  }

  Future<List<Map<String, dynamic>>> getProperties(int rentalProfileId, String token) async {
    final result = await _request(
      'GET',
      '$propertyApiBaseUrl/v1/properties/rental-profile/$rentalProfileId',
      token: token,
    );
    return _maps(result);
  }

  Future<List<Map<String, dynamic>>> getLandlordLeases(int rentalProfileId, String token) async {
    final result = await _request(
      'GET',
      '$rentApiBaseUrl/v1/leases/rental-profile/$rentalProfileId',
      token: token,
    );
    return _maps(result);
  }

  Future<Map<String, dynamic>> getTenantDetails(int userId, String token) async {
    return _request(
      'GET',
      '$rentApiBaseUrl/v1/tenants?userId=$userId',
      token: token,
    );
  }

  Future<List<Map<String, dynamic>>> getTenantLeases(int tenantId, String token) async {
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
        'POST' => await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20)),
        'GET' => await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20)),
        _ => throw const TanteApiException('Unsupported API request.'),
      };
      dynamic decoded;
      try {
        decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      } on FormatException {
        throw const TanteApiException('The server returned an unreadable response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? _string(decoded['message']) : '';
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw TanteApiException(message.isEmpty ? 'Sign-in failed. Check your phone number and password.' : message);
        }
        throw TanteApiException(message.isEmpty ? 'Request failed (${response.statusCode}).' : message);
      }
      if (decoded is Map && decoded.containsKey('success') && decoded['success'] == false) {
        throw TanteApiException(_string(decoded['message']).isEmpty ? 'The request could not be completed.' : _string(decoded['message']));
      }
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    } on TanteApiException {
      rethrow;
    } catch (_) {
      throw const TanteApiException('Could not connect to Tante. Check your connection and try again.');
    }
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static String _string(dynamic value) => value?.toString() ?? '';

  static int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(_string(value));
}
