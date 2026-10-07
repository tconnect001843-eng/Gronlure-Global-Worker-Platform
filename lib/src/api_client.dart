import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlatformApi {
  PlatformApi({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost/Profile%20Uganda/backend/public/api',
    ),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  String? get token => _token;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/register',
      body: {'full_name': fullName, 'phone': phone, 'password': password},
    );
    _token = response['token'] as String?;
    return response;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/login',
      body: {'phone': phone, 'password': password},
    );
    _token = response['token'] as String?;
    return response;
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/logout', body: const {});
    } finally {
      _token = null;
    }
  }

  Future<Map<String, dynamic>> profile() => _send('GET', '/profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profile) =>
      _send('PUT', '/profile', body: profile);

  Future<Map<String, dynamic>> startPayment({
    required String purpose,
    required String phone,
    String? workerId,
  }) => _send(
    'POST',
    '/payments/request',
    body: {'purpose': purpose, 'phone': phone, 'worker_id': ?workerId},
  );

  Future<Map<String, dynamic>> paymentStatus(String reference) => _send(
    'GET',
    '/payments/status?reference=${Uri.encodeQueryComponent(reference)}',
  );

  Future<Map<String, dynamic>> workers({String query = ''}) =>
      _send('GET', '/workers?q=${Uri.encodeQueryComponent(query)}');

  Future<Map<String, dynamic>> jobs({bool mine = false}) =>
      _send('GET', mine ? '/jobs/mine' : '/jobs');

  Future<Map<String, dynamic>> createJob({
    required String title,
    required String description,
    required String skill,
    required String location,
    int? budgetUgx,
  }) => _send(
    'POST',
    '/jobs',
    body: {
      'title': title,
      'description': description,
      'skill': skill,
      'location': location,
      'budget_ugx': budgetUgx,
    },
  );

  Future<Map<String, dynamic>> adminSummary() => _send('GET', '/admin/summary');

  Future<Map<String, dynamic>> pendingVerifications() =>
      _send('GET', '/admin/verifications');

  Future<Map<String, dynamic>> adminDisputes() =>
      _send('GET', '/admin/disputes');

  Future<Map<String, dynamic>> adminPayments() =>
      _send('GET', '/admin/payments');

  Future<void> reviewVerification(String workerId, String decision) async {
    await _send(
      'POST',
      '/admin/verifications/${Uri.encodeComponent(workerId)}',
      body: {'decision': decision},
    );
  }

  Future<void> resolveDispute(
    String disputeId,
    String decision,
    String resolution,
  ) async {
    await _send(
      'POST',
      '/admin/disputes/${Uri.encodeComponent(disputeId)}',
      body: {'decision': decision, 'resolution': resolution},
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (_token != null) headers['Authorization'] = 'Bearer $_token';

    try {
      late final http.Response response;
      switch (method) {
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        default:
          throw const ApiException('Unsupported request method.');
      }

      final dynamic decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          decoded['error'] as String? ??
              'Request failed (${response.statusCode}).',
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The server returned an invalid response.');
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the Gronlure API. Check that XAMPP is running and API_BASE_URL is correct.',
      );
    }
  }
}
