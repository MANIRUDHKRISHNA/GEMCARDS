import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../demo_customer_identity.dart';

class GemcardsApiException implements Exception {
  const GemcardsApiException(
    this.message, {
    this.statusCode,
    this.allowOfflineFallback = false,
  });

  final String message;
  final int? statusCode;
  final bool allowOfflineFallback;

  @override
  String toString() => message;
}

class GemcardsApiClient {
  GemcardsApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 2),
  }) : _httpClient = httpClient ?? http.Client(),
       baseUrl =
           (baseUrl ??
                   const String.fromEnvironment(
                     'API_BASE_URL',
                     defaultValue: 'http://10.0.2.2:8000',
                   ))
               .replaceFirst(RegExp(r'/+$'), '');

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;

  Future<Map<String, dynamic>> customer() =>
      _getMap(_customerPath('/api/v1/customer/me'));

  Future<Map<String, dynamic>> dashboard() =>
      _getMap(_customerPath('/api/v1/customer/dashboard'));

  Future<List<Map<String, dynamic>>> cards() =>
      getList(_customerPath('/api/v1/cards'));

  Future<Map<String, dynamic>> card(String id) =>
      _getMap('/api/v1/cards/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>> freezeCard(
    String id, {
    required bool frozen,
  }) => _postMap(
    '/api/v1/cards/${Uri.encodeComponent(id)}/${frozen ? 'freeze' : 'unfreeze'}',
  );

  Future<Map<String, dynamic>> updateCardControls(
    String id,
    Map<String, Object> controls,
  ) => _patchMap('/api/v1/cards/${Uri.encodeComponent(id)}/controls', controls);

  Future<Map<String, dynamic>> createVirtualCard() => _postMap(
    _customerPath('/api/v1/cards/virtual'),
    {'nickname': 'GEM Virtual', 'daily_limit': 25000},
  );

  Future<List<Map<String, dynamic>>> transactions() =>
      getList(_customerPath('/api/v1/transactions'));

  Future<Map<String, dynamic>> transaction(String id) =>
      _getMap(
        _customerPath('/api/v1/transactions/${Uri.encodeComponent(id)}'),
      );

  Future<Map<String, dynamic>> simulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) => _postMap('/api/v1/transactions/simulate', {
    'card_id': cardId,
    'merchant': merchant,
    'amount': amount,
    'country': country,
    'channel': channel,
  });

  Future<Map<String, dynamic>> rewards() =>
      _getMap(_customerPath('/api/v1/rewards'));

  Future<List<Map<String, dynamic>>> fraud() =>
      getList(_customerPath('/api/v1/fraud'));

  Future<List<Map<String, dynamic>>> disputes() =>
      getList(_customerPath('/api/v1/disputes'));

  Future<Map<String, dynamic>> createDispute({
    required String transactionId,
    required String reason,
    String details = '',
  }) => _postMap(_customerPath('/api/v1/disputes'), {
    'transaction_id': transactionId,
    'reason': reason,
    'details': details,
  });

  Future<Map<String, dynamic>> createKycSession({
    required String country,
    required String documentType,
  }) => _postMap('/api/v1/kyc/session', {
    'country': country,
    'document_type': documentType,
  });

  Future<Map<String, dynamic>> saveKycDocument(
    String sessionId, {
    required String name,
    required String dob,
    required String idNumber,
    required bool frontCaptured,
    required bool backCaptured,
  }) => _postMap('/api/v1/kyc/${Uri.encodeComponent(sessionId)}/document', {
    'name': name,
    'dob': dob,
    'id_number': idNumber,
    'front_captured': frontCaptured,
    'back_captured': backCaptured,
  });

  Future<Map<String, dynamic>> saveKycSelfie(
    String sessionId, {
    required bool livenessPassed,
    required double score,
  }) => _postMap('/api/v1/kyc/${Uri.encodeComponent(sessionId)}/selfie', {
    'liveness_passed': livenessPassed,
    'face_match_score': score,
  });

  Future<Map<String, dynamic>> saveKycAddress(
    String sessionId, {
    required String address,
    required String documentName,
  }) => _postMap('/api/v1/kyc/${Uri.encodeComponent(sessionId)}/address', {
    'address': address,
    'document_name': documentName,
  });

  Future<Map<String, dynamic>> uploadKycAddressDocument(
    String sessionId, {
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            _uri(
              '/api/v1/kyc/${Uri.encodeComponent(sessionId)}/address/upload',
            ),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
              contentType: MediaType.parse(contentType),
            ),
          );
    final response = await _send(
      () async => http.Response.fromStream(await _httpClient.send(request)),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> submitKyc(
    String sessionId, {
    required bool pepDeclared,
    required bool termsAccepted,
  }) => _postMap('/api/v1/kyc/${Uri.encodeComponent(sessionId)}/submit', {
    'pep_declared': pepDeclared,
    'terms_accepted': termsAccepted,
  });

  Future<Map<String, dynamic>> adminMetrics() =>
      _getMap('/api/v1/admin/metrics');

  Future<List<Map<String, dynamic>>> adminCustomers({
    String query = '',
    String kycStatus = '',
  }) => getList(
    Uri(
      path: '/api/v1/admin/customers',
      queryParameters: {
        if (query.isNotEmpty) 'query': query,
        if (kycStatus.isNotEmpty) 'kyc_status': kycStatus,
      },
    ).toString(),
  );

  Future<Map<String, dynamic>> adminCustomer(String id) =>
      _getMap('/api/v1/admin/customers/${Uri.encodeComponent(id)}');

  Future<List<Map<String, dynamic>>> adminCards() =>
      getList('/api/v1/admin/cards');

  Future<Map<String, dynamic>> adminCard(String id) =>
      _getMap('/api/v1/admin/cards/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>> adminUpdateCardLimit(String id, int limit) =>
      _postMap('/api/v1/admin/cards/${Uri.encodeComponent(id)}/limit', {
        'limit': limit,
      });

  Future<Map<String, dynamic>> adminReplaceCard(String id) =>
      _postMap('/api/v1/admin/cards/${Uri.encodeComponent(id)}/replace');

  Future<List<Map<String, dynamic>>> adminTransactions() =>
      getList('/api/v1/admin/transactions');

  Future<List<Map<String, dynamic>>> adminFraud() =>
      getList('/api/v1/admin/fraud');

  Future<Map<String, dynamic>> adminResolveFraud(String id) =>
      _postMap('/api/v1/fraud/${Uri.encodeComponent(id)}/resolve');

  Future<List<Map<String, dynamic>>> adminDisputes() =>
      getList('/api/v1/admin/disputes');

  Future<Map<String, dynamic>> adminUpdateDisputeStatus(
    String id,
    String status,
  ) => _postMap('/api/v1/disputes/${Uri.encodeComponent(id)}/status', {
    'status': status,
  });

  Future<Map<String, dynamic>> adminFreezeCard(
    String id, {
    required bool frozen,
  }) => _postMap(
    '/api/v1/admin/cards/${Uri.encodeComponent(id)}/${frozen ? 'freeze' : 'unfreeze'}',
  );

  Future<Map<String, dynamic>> adminSimulateAuthorization({
    required String cardId,
    required String merchant,
    required double amount,
    required String country,
    required String channel,
  }) => simulateAuthorization(
    cardId: cardId,
    merchant: merchant,
    amount: amount,
    country: country,
    channel: channel,
  );

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await _send(() => _httpClient.get(_uri(path)));
    return _decodeMap(response);
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _send(() => _httpClient.get(_uri(path)));
    final decoded = _decode(response);
    if (decoded is! List<dynamic>) {
      throw const GemcardsApiException('The server returned an invalid list.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const GemcardsApiException(
          'The server returned an invalid list item.',
        );
      }
      return item;
    }).toList();
  }

  Future<Map<String, dynamic>> _postMap(
    String path, [
    Map<String, Object>? body,
  ]) async {
    final response = await _send(
      () => _httpClient.post(
        _uri(path),
        headers: {'content-type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Map<String, Object> body,
  ) async {
    final response = await _send(
      () => _httpClient.patch(
        _uri(path),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Request failed (${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['detail'] is String) {
            message = body['detail'] as String;
          }
        } on FormatException {
          // Keep the useful HTTP status when the server body is not JSON.
        }
        throw GemcardsApiException(
          message,
          statusCode: response.statusCode,
          allowOfflineFallback: response.statusCode >= 500,
        );
      }
      return response;
    } on GemcardsApiException {
      rethrow;
    } on TimeoutException {
      throw const GemcardsApiException(
        'The GEMCARDS service timed out.',
        allowOfflineFallback: true,
      );
    } on http.ClientException catch (error) {
      throw GemcardsApiException(
        'Could not connect to GEMCARDS: $error',
        allowOfflineFallback: true,
      );
    } on Exception catch (error) {
      throw GemcardsApiException(
        'Could not connect to GEMCARDS: $error',
        allowOfflineFallback: true,
      );
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  String _customerPath(String path) {
    final uri = Uri.parse(path);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'customer_id': DemoCustomerIdentity.customerId,
          },
        )
        .toString();
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const GemcardsApiException(
        'The GEMCARDS service returned invalid JSON.',
      );
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map<String, dynamic>) {
      throw const GemcardsApiException(
        'The server returned an invalid object.',
      );
    }
    return decoded;
  }

  void close() => _httpClient.close();
}
