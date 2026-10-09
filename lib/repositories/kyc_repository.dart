import '../models/kyc_state.dart';
import '../services/api/gemcards_api_client.dart';
import '../services/demo_customer_identity.dart';

abstract class KycRepository {
  bool get isOffline;
  Future<String> startSession({
    required String country,
    required String documentType,
  });
  Future<void> saveDocument(KycState state);
  Future<void> saveSelfie(KycState state);
  Future<void> saveAddress(KycState state);
  Future<void> uploadAddressDocument(KycState state);
  Future<ProcessingStatus> submit(KycState state);
}

/// Local-only path used when the service is unavailable or in tests.
class MockKycRepository implements KycRepository {
  int _next = 1;

  @override
  bool get isOffline => true;

  @override
  Future<String> startSession({
    required String country,
    required String documentType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return 'demo-${_next++}';
  }

  @override
  Future<void> saveDocument(KycState state) async {}
  @override
  Future<void> saveSelfie(KycState state) async {}
  @override
  Future<void> saveAddress(KycState state) async {}
  @override
  Future<void> uploadAddressDocument(KycState state) async {}

  @override
  Future<ProcessingStatus> submit(KycState state) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return ProcessingStatus.verified;
  }
}

/// Falls back only when the API client identifies a recoverable service failure.
class ResilientKycRepository implements KycRepository {
  ResilientKycRepository({GemcardsApiClient? api, MockKycRepository? fallback})
    : _api = api ?? GemcardsApiClient(timeout: const Duration(seconds: 10)),
      _fallback = fallback ?? MockKycRepository();
  final GemcardsApiClient _api;
  final MockKycRepository _fallback;
  bool _offline = false;
  @override
  bool get isOffline => _offline;

  Future<T> _withFallback<T>(
    Future<T> Function() request,
    Future<T> Function() local,
  ) async {
    if (_offline) return local();
    try {
      return await request();
    } on GemcardsApiException catch (error) {
      if (!error.allowOfflineFallback) rethrow;
      _offline = true;
      return local();
    }
  }

  String _sessionId(KycState state) {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw const GemcardsApiException('Start identity verification first.');
    }
    return sessionId;
  }

  @override
  Future<String> startSession({
    required String country,
    required String documentType,
  }) => _withFallback(
    () async {
      final response = await _api.createKycSession(
        country: country,
        documentType: documentType,
      );
      final id = response['id'];
      if (id is! String || id.isEmpty) {
        throw const GemcardsApiException(
          'The service returned an invalid verification session.',
        );
      }
      final customerId = response['customer_id'];
      if (customerId is String && customerId.isNotEmpty) {
        await DemoCustomerIdentity.selectCustomer(customerId);
      }
      return id;
    },
    () => _fallback.startSession(country: country, documentType: documentType),
  );

  @override
  Future<void> saveDocument(KycState state) => _withFallback(() async {
    await _api.saveKycDocument(
      _sessionId(state),
      name: state.fullName,
      dob: state.dob,
      idNumber: state.idNumber,
      frontCaptured: state.frontCaptured,
      backCaptured: state.backCaptured,
    );
  }, () => _fallback.saveDocument(state));

  @override
  Future<void> saveSelfie(KycState state) => _withFallback(() async {
    await _api.saveKycSelfie(
      _sessionId(state),
      livenessPassed: state.livenessPassed,
      score: state.faceMatchScore,
    );
  }, () => _fallback.saveSelfie(state));

  @override
  Future<void> saveAddress(KycState state) => _withFallback(() async {
    await _api.saveKycAddress(
      _sessionId(state),
      address: state.address,
      documentName: state.addressDocument,
    );
  }, () => _fallback.saveAddress(state));

  @override
  Future<void> uploadAddressDocument(KycState state) => _withFallback(() async {
    final bytes = state.addressDocumentData;
    if (bytes == null) {
      throw const GemcardsApiException(
        'Select the proof-of-address file again before continuing.',
      );
    }
    final contentType = switch (state.addressDocument
        .split('.')
        .last
        .toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => throw const GemcardsApiException('Choose a PDF, JPG, or PNG file.'),
    };
    await _api.uploadKycAddressDocument(
      _sessionId(state),
      bytes: bytes,
      filename: state.addressDocument,
      contentType: contentType,
    );
  }, () => _fallback.uploadAddressDocument(state));

  @override
  Future<ProcessingStatus> submit(KycState state) => _withFallback(() async {
    final response = await _api.submitKyc(
      _sessionId(state),
      pepDeclared: state.pepDeclared,
      termsAccepted: state.termsAccepted,
    );
    return response['status'] == 'verified'
        ? ProcessingStatus.verified
        : ProcessingStatus.underReview;
  }, () => _fallback.submit(state));
}
