enum ProcessingStatus { draft, processing, verified, underReview, actionRequired, failed }

/// In-memory state for one demo journey. It never persists document images or
/// real identity credentials; captures are held only for the active UI flow.
class KycState {
  String? sessionId;
  String country = 'India';
  String documentType = 'National ID';
  String fullName = '';
  String dob = '';
  String idNumber = '';
  String address = '';
  String addressDocument = '';
  int? addressDocumentBytes;
  bool frontCaptured = false;
  bool backCaptured = false;
  bool selfieCaptured = false;
  bool livenessPassed = false;
  double faceMatchScore = 0;
  bool accuracyDeclared = false;
  bool pepDeclared = false;
  bool termsAccepted = false;
  String? errorMessage;
  ProcessingStatus processingStatus = ProcessingStatus.draft;

  bool get declarationsComplete => accuracyDeclared && pepDeclared && termsAccepted;

  void reset() {
    country = 'India';
    sessionId = null;
    documentType = 'National ID';
    fullName = ''; dob = ''; idNumber = ''; address = ''; addressDocument = '';
    addressDocumentBytes = null; frontCaptured = false; backCaptured = false;
    selfieCaptured = false; livenessPassed = false; faceMatchScore = 0;
    accuracyDeclared = false; pepDeclared = false; termsAccepted = false;
    errorMessage = null; processingStatus = ProcessingStatus.draft;
  }
}
