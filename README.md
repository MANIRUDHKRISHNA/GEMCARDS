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
- SQLite persistence for customer, KYC, application, and demo-domain state

## Why this backend approach?

For a two-day prototype, do **not** start with a giant banking backend. That is how humans turn a UI demo into a distributed-systems thesis.

The FastAPI layer gives us:

- clear API contracts
- easy mock verification endpoints
- a natural place to add authentication later
- a straightforward path to PostgreSQL
- a separate boundary for OCR/face/liveness vendors

The customer experience launches on the product dashboard and reads customer,
card, transaction, fraud, dispute, and reward data from the FastAPI demo. Typed
repositories fall back to an in-memory local demo when the service cannot be
reached. KYC stays in its existing verification flow and is opened from the
customer's card-application journey.

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

For an Android emulator that talks to the local FastAPI server, use
`--dart-define=API_BASE_URL=http://10.0.2.2:8000`. The default emulator URL is
already `10.0.2.2:8000`; a web or desktop run should set `API_BASE_URL` to the
host's reachable backend URL. If `GEMCARDS_DEMO_CUSTOMER_ID` is changed on the
backend, pass the same value as `--dart-define=DEMO_CUSTOMER_ID=...` for the
initial customer selection. After onboarding, the app remembers its selected
demo customer locally. If the service is unavailable, the product repositories
provide clearly labeled local demo data.

## Run the FastAPI backend

Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:GEMCARDS_DATABASE_PATH = ".\data\gemcards.sqlite3"
$env:GEMCARDS_DEMO_CUSTOMER_ID = "CUS-DEMO-001"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Linux/macOS:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export GEMCARDS_DATABASE_PATH=./data/gemcards.sqlite3
export GEMCARDS_DEMO_CUSTOMER_ID=CUS-DEMO-001
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The SQLite database is created automatically. By default it lives at
`backend/data/gemcards.sqlite3`; set `GEMCARDS_DATABASE_PATH` to use another
location. Seed demo records are inserted only into an empty database. Customer,
KYC-session, application, card, and related demo mutations survive backend
restarts. Keep this local prototype database out of source control.

## Android permissions

After `flutter create .`, add the camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

For the prototype, file access is delegated to the Android system picker rather than broad storage permissions.

## Android build troubleshooting

The wrapper uses Gradle 9.3.1 binary distribution with Android Gradle Plugin 9.1.0, Kotlin 2.4.0, and Java 17 bytecode. The build machine must have a valid `JAVA_HOME` pointing at JDK 17 or newer, Android SDK platform 36, Build Tools 28.0.3 (as reported by `flutter doctor -v`), and any NDK revision requested by Flutter installed. If Gradle reports it cannot install its distribution, verify internet access, clear the affected wrapper cache, verify the distribution URL, run `flutter doctor -v`, then retry `flutter pub get` and `flutter build apk --debug`.

The project deliberately uses the `-bin` Gradle distribution: source and documentation artifacts are not needed to build the prototype.

## API contracts

The FastAPI service retains the KYC routes below and adds deterministic customer,
card, authorization, fraud, dispute, and rewards demo routes. Interactive,
machine-readable schemas are available from `/docs` and `/openapi.json`.

### Existing KYC routes

```text
POST /api/v1/kyc/session
GET  /api/v1/kyc/{session_id}
GET  /api/v1/kyc/{session_id}/status
POST /api/v1/kyc/{session_id}/document
POST /api/v1/kyc/{session_id}/selfie
POST /api/v1/kyc/{session_id}/address
POST /api/v1/kyc/{session_id}/address/upload
POST /api/v1/kyc/{session_id}/submit
```

Starting a session without `customer_id` creates a unique synthetic customer,
a linked card application, and a pending demo card. The session response
includes `customer_id` and `application_id`. Supplying an existing customer ID
continues to support the seeded demo flow. KYC document, selfie, address,
declaration, and status fields are saved with their session; uploaded file
contents are validated in memory and are not stored. Completing the simulated
KYC flow advances the linked application and demo card. No provider performs
real identity or liveness verification.

### Customer and product routes

```text
GET    /api/v1/customer/me
GET    /api/v1/customer/dashboard
GET    /api/v1/cards
GET    /api/v1/cards/{card_id}
POST   /api/v1/cards/{card_id}/freeze
POST   /api/v1/cards/{card_id}/unfreeze
PATCH  /api/v1/cards/{card_id}/controls
POST   /api/v1/cards/virtual
GET    /api/v1/transactions
GET    /api/v1/transactions/{transaction_id}
POST   /api/v1/transactions/simulate
GET    /api/v1/fraud
POST   /api/v1/fraud/{alert_id}/resolve
GET    /api/v1/disputes
POST   /api/v1/disputes
GET    /api/v1/rewards
```

`GET /api/v1/customer/me` returns the selected synthetic customer. The dashboard
returns `{ "customer", "available_balance", "currency", "cards",
"recent_transactions", "open_fraud_alerts", "rewards" }`. The balance is
deterministic synthetic INR demo data. Customer profile/dashboard routes and
customer collection routes accept an optional `customer_id` query parameter
and return data scoped to that customer. Collection endpoints return JSON
arrays. Operations that address a card, alert, or dispute directly remain
unauthenticated demo operations; the customer ID is not an access-control check.
Card status is
`active`, `frozen`, or `closed`; control updates accept any non-empty subset of
`daily_limit` (INR, 1,000–250,000), `international_enabled`,
`contactless_enabled`, `online_enabled`, and `atm_enabled`. Virtual-card creation
accepts an optional `nickname` and `daily_limit`; it returns HTTP 201.

Authorization accepts this JSON body (`amount` is a positive INR demo amount;
`channel` is `ONLINE`, `POS`, or `ATM`):

```json
{
  "card_id": "CARD-001",
  "merchant": "Demo Market",
  "amount": 4500,
  "country": "IN",
  "channel": "ONLINE"
}
```

The response contains `decision` (`APPROVED`, `DECLINED`, or `FLAGGED`),
`authorization_id`, `reasons`, and `rule_results`. Declines cover inactive or
frozen cards, amounts over the card's daily limit, and foreign usage when
international transactions are disabled. High-value foreign attempts at or
above INR 7,500 are marked for review when not hard-declined and create a fraud
alert. Each simulated authorization is also added to the transaction feed.
Disabling the online or ATM card control declines the matching `ONLINE` or
`ATM` channel; `POS` remains available because the request does not indicate
contactless use.

Dispute creation accepts `transaction_id`, `reason`, and optional `details`;
declined transactions cannot be disputed. Fraud resolution has no request body
and marks the named alert resolved. Missing resources return HTTP 404 and
invalid request data returns HTTP 422.

The customer identity selector is a **temporary demo selector, not
authentication**. The app stores the active customer ID in device-local
preferences after a KYC session starts, then sends it to customer endpoints as
`customer_id`; a newly created applicant becomes the active demo selection.
The backend defaults to `GEMCARDS_DEMO_CUSTOMER_ID` (the seeded demo customer
unless configured otherwise). IDs can be changed or spoofed by a client, and
must never be treated as authorization or used with real personal data.

Seed data is synthetic and is inserted into an empty SQLite database. Mutations
persist across backend restarts. These APIs do not move money, issue real cards,
contact financial services, or verify real identities.

### Flutter integration

`GemcardsApiClient` is the shared HTTP boundary. `CustomerRepository`,
`CardRepository`, `TransactionRepository`, and `AdminRepository` decode backend
responses into typed Flutter models. The customer dashboard reads `/customer/me`
and `/customer/dashboard`; card controls and virtual-card creation use the card
routes above; activity and details read the transaction routes; rewards,
security activity, and disputes read their corresponding collections. Card
authorization is sent to `POST /api/v1/transactions/simulate`; the UI renders
the backend decision and rule results. The admin demo loads its portfolio,
customer, card, transaction, fraud, and dispute views from the existing
`/api/v1/admin/*` routes.

If a request cannot reach the service or the service returns a server error,
repositories use local deterministic demo data and mark the customer screen as
offline demo mode. Client errors such as invalid card operations remain visible
instead of being converted into successful mock results. The backend remains
in-memory and is the authoritative source only while reachable.

The balance display, rewards redemption, support content, masked virtual-card
security details, and KYC/liveness outcomes are still demo-only because no
corresponding production APIs or payment providers are part of this prototype.

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


