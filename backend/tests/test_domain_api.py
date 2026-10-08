from fastapi.testclient import TestClient

from app.domain import store
from app.api.routes import admin as admin_routes
from app.main import app

client = TestClient(app)


def test_card_retrieval_returns_seeded_card() -> None:
    response = client.get("/api/v1/cards/CARD-001")
    cards = client.get("/api/v1/cards")

    assert response.status_code == 200
    assert response.json()["masked_number"] == "•••• 4821"
    assert response.json()["status"] == "active"
    assert any(card["id"] == "CARD-001" for card in cards.json())


def test_card_can_be_frozen_and_unfrozen() -> None:
    frozen = client.post("/api/v1/cards/CARD-001/freeze")
    declined = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-001",
            "merchant": "Demo Market",
            "amount": 100,
            "country": "IN",
            "channel": "POS",
        },
    )
    unfrozen = client.post("/api/v1/cards/CARD-001/unfreeze")

    assert frozen.status_code == 200
    assert frozen.json()["status"] == "frozen"
    assert declined.json()["decision"] == "DECLINED"
    assert unfrozen.status_code == 200
    assert unfrozen.json()["status"] == "active"


def test_authorization_is_approved_within_card_limit() -> None:
    response = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-001",
            "merchant": "Demo Market",
            "amount": 4500,
            "country": "IN",
            "channel": "ONLINE",
        },
    )

    assert response.status_code == 200
    assert response.json()["decision"] == "APPROVED"
    assert response.json()["authorization_id"].startswith("AUTH-DEMO-")
    assert response.json()["reasons"] == []
    assert len(response.json()["rule_results"]) == 5


def test_authorization_is_declined_over_daily_limit() -> None:
    response = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-001",
            "merchant": "Demo Market",
            "amount": 50001,
            "country": "IN",
            "channel": "POS",
        },
    )

    assert response.status_code == 200
    assert response.json()["decision"] == "DECLINED"
    assert "Amount exceeds the daily limit" in response.json()["reasons"]


def test_foreign_authorization_is_declined_when_international_is_disabled() -> None:
    response = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-001",
            "merchant": "Demo Market",
            "amount": 1000,
            "country": "SG",
            "channel": "ONLINE",
        },
    )

    assert response.status_code == 200
    assert response.json()["decision"] == "DECLINED"
    assert "International usage is disabled" in response.json()["reasons"]


def test_disabled_online_channel_is_declined() -> None:
    disabled = client.patch(
        "/api/v1/cards/CARD-001/controls",
        json={"online_enabled": False},
    )
    response = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-001",
            "merchant": "Demo Market",
            "amount": 1000,
            "country": "IN",
            "channel": "ONLINE",
        },
    )
    client.patch(
        "/api/v1/cards/CARD-001/controls",
        json={"online_enabled": True},
    )

    assert disabled.status_code == 200
    assert response.json()["decision"] == "DECLINED"
    assert "ONLINE transactions are disabled" in response.json()["reasons"]


def test_high_value_foreign_transaction_is_flagged_and_creates_alert() -> None:
    response = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-003",
            "merchant": "Demo Electronics",
            "amount": 9800,
            "country": "SG",
            "channel": "ONLINE",
        },
    )

    assert response.status_code == 200
    assert response.json()["decision"] == "FLAGGED"
    assert any("foreign" in reason.lower() for reason in response.json()["reasons"])

    alerts = client.get("/api/v1/fraud")
    transactions = client.get("/api/v1/transactions")
    flagged_transaction = next(
        transaction
        for transaction in transactions.json()
        if transaction["authorization_id"] == response.json()["authorization_id"]
    )
    transaction_detail = client.get(
        f"/api/v1/transactions/{flagged_transaction['id']}"
    )
    assert alerts.status_code == 200
    assert transaction_detail.status_code == 200
    assert transaction_detail.json()["decision"] == "FLAGGED"
    assert any(
        alert["transaction_id"] == flagged_transaction["id"]
        for alert in alerts.json()
    )


def test_fraud_retrieval_includes_deterministic_seed_alert() -> None:
    response = client.get("/api/v1/fraud")
    resolved = client.post("/api/v1/fraud/FRA-01/resolve")

    assert response.status_code == 200
    assert response.json()[0]["id"] == "FRA-01"
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"


def test_customer_dashboard_disputes_rewards_and_virtual_card() -> None:
    customer = client.get("/api/v1/customer/me")
    dashboard = client.get("/api/v1/customer/dashboard")
    rewards = client.get("/api/v1/rewards")
    dispute = client.post(
        "/api/v1/disputes",
        json={"transaction_id": "TXN-101", "reason": "Unrecognized merchant"},
    )
    virtual_card = client.post("/api/v1/cards/virtual", json={})
    disputes = client.get("/api/v1/disputes")

    assert customer.status_code == 200
    assert customer.json()["id"] == "CUS-DEMO-001"
    assert customer.json()["application_status"] == "card_active"
    assert dashboard.status_code == 200
    assert dashboard.json()["customer"]["id"] == "CUS-DEMO-001"
    assert dashboard.json()["available_balance"] == 24680
    assert dashboard.json()["currency"] == "INR"
    assert rewards.status_code == 200
    assert rewards.json()["points"] == 1240
    assert dispute.status_code == 201
    assert dispute.json()["status"] == "open"
    assert disputes.status_code == 200
    assert any(
        item["id"] == dispute.json()["id"] for item in disputes.json()
    )
    assert virtual_card.status_code == 201
    assert virtual_card.json()["card_type"] == "virtual"


def test_kyc_updates_the_customer_application_lifecycle() -> None:
    customer = store.get_customer(store.DEMO_CUSTOMER_ID)
    original_kyc_status = customer.kyc_status
    original_application_status = customer.application_status
    customer.kyc_status = "pending"
    customer.application_status = "draft"

    try:
        created = client.post(
            "/api/v1/kyc/session",
            json={"country": "India", "document_type": "National ID"},
        )
        assert created.status_code == 200
        assert client.get("/api/v1/customer/me").json()["application_status"] == (
            "kyc_in_progress"
        )

        submitted = client.post(
            f"/api/v1/kyc/{created.json()['id']}/submit",
            json={"pep_declared": False, "terms_accepted": True},
        )
        customer_response = client.get("/api/v1/customer/me")

        assert submitted.status_code == 200
        assert customer_response.json()["kyc_status"] == "verified"
        assert customer_response.json()["application_status"] == "kyc_verified"
    finally:
        customer.kyc_status = original_kyc_status
        customer.application_status = original_application_status


def test_admin_card_limit_and_dispute_status_update_shared_domain_state() -> None:
    card = store.get_card("CARD-001")
    original_limit = card.daily_limit
    admin_card = next(item for item in admin_routes.CARDS if item["id"] == "CARD-001")
    original_admin_limit = admin_card["limit"]
    dispute = store.disputes["DSP-01"]
    original_status = dispute.status

    try:
        changed_limit = client.post(
            "/api/v1/admin/cards/CARD-001/limit",
            json={"limit": 60000},
        )
        authorization = client.post(
            "/api/v1/transactions/simulate",
            json={
                "card_id": "CARD-001",
                "merchant": "Ops limit verification",
                "amount": 60001,
                "country": "IN",
                "channel": "ONLINE",
            },
        )
        changed_dispute = client.post(
            "/api/v1/disputes/DSP-01/status",
            json={"status": "investigating"},
        )
        listed_disputes = client.get("/api/v1/disputes")

        assert changed_limit.status_code == 200
        assert changed_limit.json()["limit"] == 60000
        assert card.daily_limit == 60000
        assert authorization.json()["decision"] == "DECLINED"
        assert changed_dispute.status_code == 200
        assert changed_dispute.json()["status"] == "investigating"
        assert next(
            item for item in listed_disputes.json() if item["id"] == "DSP-01"
        )["status"] == "investigating"
    finally:
        card.daily_limit = original_limit
        admin_card["limit"] = original_admin_limit
        dispute.status = original_status
