# GEMCARDS Onboarding Prototype

A GEMCARDS customer-onboarding demonstration built with Flutter/Dart and a small FastAPI backend. GEMCARDS is Gemini Software Solutions' retail payment suite for card issuance, card lifecycle management and transaction processing.

> **Prototype disclaimer:** This is an engineering/demo prototype. It is not production KYC, does not perform government identity verification, and must not be used with real Aadhaar, PAN, passport, financial, or biometric data.

## Goal

Build a convincing end-to-end KYC journey by the 10th, while keeping the architecture clean enough to replace mock services with approved production providers later.

## Six-frame journey

1. **Identity & document selection**
2. **Government ID capture + OCR confirmation**
3. **Selfie/liveness prototype**
4. **Proof of address**
5. **Review + self-declaration**
6. **Processing + outcome**

## Stack

### Mobile

- Flutter / Dart
- `camera` for the live camera preview and capture UI
- Google ML Kit text recognition for local OCR experimentation
- `file_picker` for proof-of-address documents
- `http` for backend integration
- Material 3 UI with a restrained banking visual system

### Backend

- FastAPI
- Pydantic
- In-memory mock verification state for the prototype
- SQLite/PostgreSQL can be introduced after the UX prototype is accepted

## Why this backend approach?

For a two-day prototype, do **not** start with a giant banking backend. That is how humans turn a UI demo into a distributed-systems thesis.

The FastAPI layer gives us:

- clear API contracts
- easy mock verification endpoints
- a natural place to add authentication later
- a straightforward path to PostgreSQL
- a separate boundary for OCR/face/liveness vendors

The Flutter app currently defaults to a local/mock verification service so the UI can be developed without credentials or production KYC integrations.

## Important prototype boundaries

The app intentionally uses simulated outcomes for:

- face match
- active/passive liveness
- document authenticity
- sanctions/PEP screening
- final KYC decision

ML Kit OCR is included as a real local capability, but OCR output should still be treated as untrusted input until a compliant verification provider validates it.

## Run the Flutter app

The Android Gradle wrapper and Flutter platform scaffolding are committed. With Flutter installed:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

For an Android emulator that talks to the local FastAPI server, use `--dart-define=API_BASE_URL=http://10.0.2.2:8000`. The app continues to demonstrate its local flow when a provider is unavailable.

## Run the FastAPI backend

Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Linux/macOS:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Android permissions

After `flutter create .`, add the camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

For the prototype, file access is delegated to the Android system picker rather than broad storage permissions.

## Android build troubleshooting

The wrapper uses Gradle 9.3.1 binary distribution with Android Gradle Plugin 9.1.0, Kotlin 2.4.0, and Java 17 bytecode. The build machine must have a valid `JAVA_HOME` pointing at JDK 17 or newer, Android SDK platform 36, Build Tools 28.0.3 (as reported by `flutter doctor -v`), and any NDK revision requested by Flutter installed. If Gradle reports it cannot install its distribution, verify internet access, clear the affected wrapper cache, verify the distribution URL, run `flutter doctor -v`, then retry `flutter pub get` and `flutter build apk --debug`.

The project deliberately uses the `-bin` Gradle distribution: source and documentation artifacts are not needed to build the prototype.

## Suggested API contract

```text
POST /api/v1/kyc/session
POST /api/v1/kyc/{session_id}/document
POST /api/v1/kyc/{session_id}/selfie
POST /api/v1/kyc/{session_id}/address
POST /api/v1/kyc/{session_id}/submit
GET  /api/v1/kyc/{session_id}
```

## Two-day plan

### Day 1: make the journey feel real

- Finish all six screens
- Camera preview + document capture
- OCR extraction and editable confirmation
- Selfie/liveness simulation
- Address upload
- Review screen
- Processing state animation

### Day 2: make it demo-ready

- Backend wiring
- Validation and error states
- Loading states
- Retry paths
- Accessibility pass
- Android build
- Test on a real phone
- Final polish and demo script

## Production roadmap

After the prototype is approved, the next architecture step should be a provider abstraction around:

- KYC/CKYC verification
- PAN validation
- Aadhaar/VID flows through authorized channels
- DigiLocker/document retrieval where legally applicable
- OCR/document authenticity
- face match and liveness
- PEP/sanctions screening
- consent/audit logging
- encrypted object storage
- PostgreSQL-backed KYC state machine

Never place provider secrets, Aadhaar numbers, PAN numbers, biometric images, or real identity documents in the Git repository.
