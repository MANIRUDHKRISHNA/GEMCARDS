import '../models/kyc_state.dart';
import '../services/kyc_api_service.dart';

abstract class KycRepository {
  Future<String> startSession({required String country, required String documentType});
  Future<void> saveDocument(KycState state);
  Future<void> saveSelfie(KycState state);
  Future<void> saveAddress(KycState state);
  Future<ProcessingStatus> submit(KycState state);
}

/// Reliable offline path for a demo. A network implementation can be selected
/// later without changing any screen logic.
class MockKycRepository implements KycRepository {
  int _next = 1;

  @override
  Future<String> startSession({required String country, required String documentType}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return 'demo-${_next++}';
  }
  @override Future<void> saveDocument(KycState state) async {}
  @override Future<void> saveSelfie(KycState state) async {}
  @override Future<void> saveAddress(KycState state) async {}

  @override
  Future<ProcessingStatus> submit(KycState state) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return ProcessingStatus.verified;
  }
}

/// Uses FastAPI when it is reachable; local demo mode keeps the journey usable
/// when a developer has not started the backend.
class ResilientKycRepository implements KycRepository {
  ResilientKycRepository({KycApiService? api, MockKycRepository? fallback}) : _api = api ?? KycApiService(), _fallback = fallback ?? MockKycRepository();
  final KycApiService _api;
  final MockKycRepository _fallback;
  bool _offline = false;
  Future<T> _tryApi<T>(Future<T> Function() request, Future<T> Function() local) async { if (_offline) return local(); try { return await request(); } catch (_) { _offline = true; return local(); } }
  @override Future<String> startSession({required String country, required String documentType}) => _tryApi(() => _api.createSession(country: country, documentType: documentType), () => _fallback.startSession(country: country, documentType: documentType));
  @override Future<void> saveDocument(KycState state) => _tryApi(() => _api.saveDocument(state.sessionId!, name: state.fullName.isEmpty ? 'Alex Morgan' : state.fullName, dob: state.dob.isEmpty ? '14 Aug 2000' : state.dob, idNumber: state.idNumber.isEmpty ? 'XXXX4821' : state.idNumber, frontCaptured: state.frontCaptured, backCaptured: state.backCaptured), () => _fallback.saveDocument(state));
  @override Future<void> saveSelfie(KycState state) => _tryApi(() => _api.saveSelfie(state.sessionId!, livenessPassed: state.livenessPassed, score: state.faceMatchScore), () => _fallback.saveSelfie(state));
  @override Future<void> saveAddress(KycState state) => _tryApi(() => _api.saveAddress(state.sessionId!, address: state.address, documentName: state.addressDocument), () => _fallback.saveAddress(state));
  @override Future<ProcessingStatus> submit(KycState state) => _tryApi(() async { final status = await _api.submit(state.sessionId!, pepDeclared: state.pepDeclared, termsAccepted: state.termsAccepted); return status == 'verified' ? ProcessingStatus.verified : ProcessingStatus.underReview; }, () => _fallback.submit(state));
}
