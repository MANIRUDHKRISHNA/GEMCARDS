from fastapi.testclient import TestClient

from app.api.routes import kyc
from app.domain import database, store
from app.main import app

client = TestClient(app)


def _create_applicant() -> tuple[str, str, str]:
    response = client.post(
        "/api/v1/kyc/session",
        json={"country": "India", "document_type": "National ID"},
    )
    assert response.status_code == 200
    body = response.json()
    return body["id"], body["customer_id"], body["application_id"]


def test_kyc_sessions_create_unique_customers_visible_to_admin() -> None:
    first_session, first_customer, application_id = _create_applicant()
    second_session, second_customer, _ = _create_applicant()

    assert first_customer != second_customer
    assert first_session != second_session

    customers = client.get("/api/v1/admin/customers").json()
    first_detail = client.get(
        f"/api/v1/admin/customers/{first_customer}"
    ).json()
    assert first_customer in {customer["id"] for customer in customers}
    assert first_detail["kyc_status"] == "in_progress"
    assert first_detail["application_status"] == "kyc_in_progress"
    assert first_detail["cards_detail"][0]["id"] == store.card_applications[
        application_id
    ].card_id


def test_invalid_kyc_session_requests_do_not_create_customers() -> None:
    customer_count = len(store.customers)

    invalid_country = client.post(
        "/api/v1/kyc/session",
        json={"country": " ", "document_type": "National ID"},
    )
    invalid_document = client.post(
        "/api/v1/kyc/session",
        json={"country": "India", "document_type": "Identity Card"},
    )
    unknown_customer = client.post(
        "/api/v1/kyc/session",
        json={
            "country": "India",
            "document_type": "National ID",
            "customer_id": "CUS-DOES-NOT-EXIST",
        },
    )

    assert invalid_country.status_code == 422
    assert invalid_document.status_code == 422
    assert unknown_customer.status_code == 404
    assert len(store.customers) == customer_count


def test_database_failures_return_a_service_error(monkeypatch) -> None:
    def fail_save(entity: str, payload: dict[str, object]) -> None:
        assert entity == "customers"
        assert payload["id"]
        raise database.DatabaseError("storage unavailable")

    monkeypatch.setattr(database, "save_entity", fail_save)
    response = client.post(
        "/api/v1/kyc/session",
        json={"country": "India", "document_type": "National ID"},
    )

    assert response.status_code == 503
    assert response.json() == {
        "detail": "Persistent demo storage is temporarily unavailable"
    }


def test_customer_identity_scopes_dashboard_and_is_restored_after_reconnect(
    tmp_path,
) -> None:
    session_id, customer_id, application_id = _create_applicant()
    customer_card_id = store.card_applications[application_id].card_id

    default_dashboard = client.get("/api/v1/customer/dashboard").json()
    applicant_dashboard = client.get(
        "/api/v1/customer/dashboard",
        params={"customer_id": customer_id},
    ).json()
    applicant_customer = client.get(
        "/api/v1/customer/me",
        params={"customer_id": customer_id},
    ).json()
    applicant_cards = client.get(
        "/api/v1/cards",
        params={"customer_id": customer_id},
    ).json()

    assert default_dashboard["customer"]["id"] == store.DEMO_CUSTOMER_ID
    assert applicant_customer["id"] == customer_id
    assert applicant_dashboard["cards"][0]["id"] == customer_card_id
    assert [card["id"] for card in applicant_cards] == [customer_card_id]
    assert applicant_dashboard["recent_transactions"] == []
    assert applicant_dashboard["available_balance"] == 0

    path = tmp_path / "gemcards-test.sqlite3"
    store.configure_database(path)
    kyc.reload_sessions()

    session = client.get(f"/api/v1/kyc/{session_id}").json()
    customer_detail = client.get(
        f"/api/v1/admin/customers/{customer_id}"
    ).json()
    assert session["customer_id"] == customer_id
    assert customer_detail["application_status"] == "kyc_in_progress"
    assert customer_detail["cards_detail"][0]["id"] == customer_card_id


def test_kyc_data_and_card_application_survive_database_reconnection(
    tmp_path,
) -> None:
    session_id, customer_id, application_id = _create_applicant()
    card_id = store.card_applications[application_id].card_id

    assert client.post(
        f"/api/v1/kyc/{session_id}/document",
        json={
            "name": "Synthetic Applicant",
            "dob": "1990-01-01",
            "id_number": "SAMPLE-1234",
        },
    ).status_code == 200
    assert client.post(
        f"/api/v1/kyc/{session_id}/selfie",
        json={"liveness_passed": True, "face_match_score": 0.96},
    ).status_code == 200
    assert client.post(
        f"/api/v1/kyc/{session_id}/address",
        json={
            "address": "42 Sample Street, Bengaluru",
            "document_name": "sample-bill.pdf",
        },
    ).status_code == 200
    uploaded = client.post(
        f"/api/v1/kyc/{session_id}/address/upload",
        files={"file": ("sample-bill.pdf", b"synthetic", "application/pdf")},
    )
    assert uploaded.status_code == 200

    path = tmp_path / "gemcards-test.sqlite3"
    store.configure_database(path)
    kyc.reload_sessions()

    restored_session = client.get(f"/api/v1/kyc/{session_id}").json()
    assert restored_session["customer_id"] == customer_id
    assert restored_session["document"]["id_number"] == "SAMPLE-1234"
    assert restored_session["address_upload"]["filename"] == "sample-bill.pdf"
    assert client.post(
        f"/api/v1/kyc/{session_id}/submit",
        json={"pep_declared": False, "terms_accepted": True},
    ).json()["status"] == "verified"

    store.configure_database(path)
    kyc.reload_sessions()
    final_session = client.get(f"/api/v1/kyc/{session_id}").json()
    final_customer = client.get(
        f"/api/v1/admin/customers/{customer_id}"
    ).json()

    assert final_session["status"] == "verified"
    assert final_customer["kyc_status"] == "verified"
    assert final_customer["application_status"] == "card_active"
    assert client.get(f"/api/v1/cards/{card_id}").json()["status"] == "active"
