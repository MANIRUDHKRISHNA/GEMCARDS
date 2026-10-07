class KycState {
  String country = 'India';
  String documentType = 'National ID Card';

  String fullName = 'Demo Applicant';
  String dob = '14 Aug 2005';
  String idNumber = 'XXXX-XXXX-1234';

  String address = '';
  String addressDocument = '';

  bool frontCaptured = false;
  bool backCaptured = false;
  bool livenessPassed = false;
  double faceMatchScore = 0;

  bool pepDeclared = false;
  bool termsAccepted = false;

  void reset() {
    country = 'India';
    documentType = 'National ID Card';
    fullName = 'Demo Applicant';
    dob = '14 Aug 2005';
    idNumber = 'XXXX-XXXX-1234';
    address = '';
    addressDocument = '';
    frontCaptured = false;
    backCaptured = false;
    livenessPassed = false;
    faceMatchScore = 0;
    pepDeclared = false;
    termsAccepted = false;
  }
}
