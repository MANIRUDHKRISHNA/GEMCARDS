from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def create_session() -> str:
    response = client.post('/api/v1/kyc/session', json={'country': 'India', 'document_type': 'National ID'})
    assert response.status_code == 200
    return response.json()['id']


def test_health() -> None:
    assert client.get('/health').json()['status'] == 'ok'


def test_full_demo_contract() -> None:
    session_id = create_session()
    assert client.get(f'/api/v1/kyc/{session_id}').status_code == 200
    assert client.post(f'/api/v1/kyc/{session_id}/document', json={'name': 'Demo Applicant', 'dob': '14 Aug 2005', 'id_number': 'DEMO1234'}).status_code == 200
    assert client.post(f'/api/v1/kyc/{session_id}/selfie', json={'liveness_passed': True, 'face_match_score': .96}).status_code == 200
    assert client.post(f'/api/v1/kyc/{session_id}/address', json={'address': '1 Demo Street, Bengaluru', 'document_name': 'bill.pdf'}).status_code == 200
    assert client.post(f'/api/v1/kyc/{session_id}/submit', json={'pep_declared': True, 'terms_accepted': True}).json()['status'] == 'verified'
    assert client.get(f'/api/v1/kyc/{session_id}/status').json()['status'] == 'verified'


def test_upload_rejects_invalid_type() -> None:
    session_id = create_session()
    response = client.post(f'/api/v1/kyc/{session_id}/address/upload', files={'file': ('unsafe.txt', b'x', 'text/plain')})
    assert response.status_code == 415
