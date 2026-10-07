import 'dart:convert';

import 'package:http/http.dart' as http;

class KycApiService {
  KycApiService({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000',
        );

  final String baseUrl;
  String? sessionId;

  Future<void> createSession({
    required String country,
    required String documentType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/kyc/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'country': country,
        'document_type': documentType,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('Unable to create KYC session: ${response.body}');
    }

    sessionId = (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }
}
