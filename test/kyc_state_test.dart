import 'package:flutter_test/flutter_test.dart';
import 'package:nsdl_jiffy_kyc_prototype/models/kyc_state.dart';
import 'package:nsdl_jiffy_kyc_prototype/repositories/kyc_repository.dart';

void main() {
  test('review declarations require explicit acceptance', () {
    final state = KycState();
    expect(state.declarationsComplete, isFalse);
    state.accuracyDeclared = true;
    state.pepDeclared = true;
    state.termsAccepted = true;
    expect(state.declarationsComplete, isTrue);
  });

  test('mock repository creates a demo session and verified result', () async {
    final repository = MockKycRepository();
    expect(await repository.startSession(country: 'India', documentType: 'National ID'), 'demo-1');
    expect(await repository.submit(KycState()), ProcessingStatus.verified);
  });
}
