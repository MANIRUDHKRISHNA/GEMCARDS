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

  Future<String> createSession({
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
    return sessionId!;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 4));
    if (response.statusCode >= 400) throw Exception('API request failed (${response.statusCode})');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> saveDocument(String id, {required String name, required String dob, required String idNumber, required bool frontCaptured, required bool backCaptured}) => _post('/api/v1/kyc/$id/document', {'name': name, 'dob': dob, 'id_number': idNumber, 'front_captured': frontCaptured, 'back_captured': backCaptured});
  Future<void> saveSelfie(String id, {required bool livenessPassed, required double score}) => _post('/api/v1/kyc/$id/selfie', {'liveness_passed': livenessPassed, 'face_match_score': score});
  Future<void> saveAddress(String id, {required String address, required String documentName}) => _post('/api/v1/kyc/$id/address', {'address': address, 'document_name': documentName});
  Future<String> submit(String id, {required bool pepDeclared, required bool termsAccepted}) async => (await _post('/api/v1/kyc/$id/submit', {'pep_declared': pepDeclared, 'terms_accepted': termsAccepted}))['status'] as String;
}
