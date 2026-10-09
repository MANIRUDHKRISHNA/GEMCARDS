import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemcards_onboarding_prototype/models/kyc_state.dart';
import 'package:gemcards_onboarding_prototype/repositories/kyc_repository.dart';
import 'package:gemcards_onboarding_prototype/services/api/gemcards_api_client.dart';
import 'package:gemcards_onboarding_prototype/services/demo_customer_identity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'KYC contract errors are surfaced instead of silently falling back',
    () async {
      final repository = ResilientKycRepository(
        api: GemcardsApiClient(
          baseUrl: 'http://gemcards.test',
          httpClient: MockClient(
            (_) async => http.Response(
              '{"detail":"Unsupported document type"}',
              422,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

      await expectLater(
        repository.startSession(country: 'India', documentType: 'National ID'),
        throwsA(
          isA<GemcardsApiException>().having(
            (error) => error.message,
            'message',
            'Unsupported document type',
          ),
        ),
      );
      expect(repository.isOffline, isFalse);
    },
  );

  test('recoverable service failures activate the offline KYC path', () async {
    final repository = ResilientKycRepository(
      api: GemcardsApiClient(
        baseUrl: 'http://gemcards.test',
        httpClient: MockClient((_) async => http.Response('Unavailable', 503)),
      ),
    );

    expect(
      await repository.startSession(
        country: 'India',
        documentType: 'National ID',
      ),
      'demo-1',
    );
    expect(repository.isOffline, isTrue);
  });

  test(
    'KYC documents, address uploads, and submission use shared API routes',
    () async {
      final requests = <http.Request>[];
      final repository = ResilientKycRepository(
        api: GemcardsApiClient(
          baseUrl: 'http://gemcards.test',
          httpClient: MockClient((request) async {
            requests.add(request);
            final body = switch (request.url.path) {
              '/api/v1/kyc/session' => {'id': 'KYC-001'},
              '/api/v1/kyc/KYC-001/submit' => {'status': 'verified'},
              _ => <String, Object>{'accepted': true},
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final state = KycState()
        ..fullName = 'Sample Customer'
        ..dob = '01 Jan 2000'
        ..idNumber = 'SAMPLE1234'
        ..frontCaptured = true
        ..backCaptured = true
        ..livenessPassed = true
        ..faceMatchScore = .96
        ..address = '42 Sample Street'
        ..addressDocument = 'sample.pdf'
        ..addressDocumentData = Uint8List.fromList([1, 2, 3])
        ..accuracyDeclared = true
        ..pepDeclared = true
        ..termsAccepted = true;

      state.sessionId = await repository.startSession(
        country: state.country,
        documentType: state.documentType,
      );
      await repository.saveDocument(state);
      await repository.saveSelfie(state);
      await repository.saveAddress(state);
      await repository.uploadAddressDocument(state);
      expect(await repository.submit(state), ProcessingStatus.verified);
      expect(repository.isOffline, isFalse);
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'POST /api/v1/kyc/session',
          'POST /api/v1/kyc/KYC-001/document',
          'POST /api/v1/kyc/KYC-001/selfie',
          'POST /api/v1/kyc/KYC-001/address',
          'POST /api/v1/kyc/KYC-001/address/upload',
          'POST /api/v1/kyc/KYC-001/submit',
        ],
      );
      expect(
        requests[4].headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
    },
  );

  test('KYC session selects and persists the returned demo customer', () async {
    SharedPreferences.setMockInitialValues({});
    await DemoCustomerIdentity.initialize();
    final requests = <http.Request>[];
    final api = GemcardsApiClient(
      baseUrl: 'http://gemcards.test',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path == '/api/v1/kyc/session'
              ? '{"id":"KYC-NEW","customer_id":"CUS-000042"}'
              : '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ResilientKycRepository(api: api);

    await repository.startSession(
      country: 'India',
      documentType: 'National ID',
    );
    await api.customer();

    final preferences = await SharedPreferences.getInstance();
    expect(DemoCustomerIdentity.customerId, 'CUS-000042');
    expect(preferences.getString('gemcards.demo_customer_id'), 'CUS-000042');
    expect(requests.last.url.queryParameters['customer_id'], 'CUS-000042');
    await DemoCustomerIdentity.initialize();
    expect(DemoCustomerIdentity.customerId, 'CUS-000042');
  });
}
