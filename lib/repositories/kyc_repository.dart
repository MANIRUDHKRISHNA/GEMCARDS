import '../models/kyc_state.dart';

abstract class KycRepository {
  Future<String> startSession({required String country, required String documentType});
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

  @override
  Future<ProcessingStatus> submit(KycState state) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return ProcessingStatus.verified;
  }
}
