from fastapi.testclient import TestClient

from app.domain import store
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
    event_types = {
        event["event_type"] for event in client.get("/api/v1/admin/audit").json()
    }
    assert {"CARD_FROZEN", "CARD_UNFROZEN", "TRANSACTION_DECLINED"} <= event_types


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
    assert any(
        event["event_type"] == "TRANSACTION_APPROVED"
        and event["transaction_id"]
        for event in client.get("/api/v1/admin/audit").json()
    )


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
    transaction = next(
        item
        for item in client.get("/api/v1/transactions").json()
        if item["authorization_id"] == response.json()["authorization_id"]
    )
    assert any(
        event["event_type"] == "TRANSACTION_DECLINED"
        and event["transaction_id"] == transaction["id"]
        for event in client.get("/api/v1/admin/audit").json()
    )


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
    alert = next(
        alert
        for alert in alerts.json()
        if alert["transaction_id"] == flagged_transaction["id"]
    )
    assert alert["customer_id"] == store.get_card("CARD-003").customer_id
    assert alert["severity"] == "medium"
    assert any(
        event["event_type"] == "FRAUD_ALERT_CREATED"
        and event["transaction_id"] == flagged_transaction["id"]
        for event in client.get("/api/v1/admin/audit").json()
    )


def test_fraud_retrieval_includes_deterministic_seed_alert() -> None:
    response = client.get("/api/v1/fraud")
    resolved = client.post("/api/v1/fraud/FRA-01/resolve")

    assert response.status_code == 200
    assert response.json()[0]["id"] == "FRA-01"
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    assert any(
        event["event_type"] == "FRAUD_ALERT_RESOLVED"
        and event["transaction_id"] == "TXN-103"
        for event in client.get("/api/v1/admin/audit").json()
    )


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
    expected_points = int(
        sum(
            transaction.amount
            for transaction in store.transactions.values()
            if store.get_card(transaction.card_id).customer_id
            == store.DEMO_CUSTOMER_ID
            and transaction.decision == "APPROVED"
        )
        // 10
    )

    assert customer.status_code == 200
    assert customer.json()["id"] == "CUS-DEMO-001"
    assert customer.json()["application_status"] == "card_active"
    assert dashboard.status_code == 200
    assert dashboard.json()["customer"]["id"] == "CUS-DEMO-001"
    assert dashboard.json()["available_balance"] == 24680
    assert dashboard.json()["currency"] == "INR"
    assert rewards.status_code == 200
    assert rewards.json()["points"] == expected_points
    assert rewards.json()["available_value"] == expected_points / 10
    assert dispute.status_code == 201
    assert dispute.json()["status"] == "open"
    assert disputes.status_code == 200
    assert any(
        item["id"] == dispute.json()["id"] for item in disputes.json()
    )
    assert dispute.json()["customer_id"] == store.get_card(
        "CARD-001"
    ).customer_id
    assert any(
        event["event_type"] == "DISPUTE_OPENED"
        and event["dispute_id"] == dispute.json()["id"]
        and event["transaction_id"] == "TXN-101"
        for event in client.get("/api/v1/admin/audit").json()
    )
    assert virtual_card.status_code == 201
    assert virtual_card.json()["card_type"] == "virtual"


def test_kyc_updates_the_customer_application_lifecycle() -> None:
    customer = store.get_customer("CUS-DEMO-003")
    original_kyc_status = customer.kyc_status
    original_application_status = customer.application_status
    customer.kyc_status = "pending"
    customer.application_status = "draft"

    try:
        created = client.post(
            "/api/v1/kyc/session",
            json={
                "country": "India",
                "document_type": "National ID",
                "customer_id": customer.id,
            },
        )
        assert created.status_code == 200
        assert client.get(
            f"/api/v1/admin/customers/{customer.id}"
        ).json()["application_status"] == "kyc_in_progress"

        session_id = created.json()["id"]
        assert client.post(
            f"/api/v1/kyc/{session_id}/document",
            json={
                "name": "Jordan Lee",
                "dob": "1990-01-01",
                "id_number": "DEMO-3003",
            },
        ).status_code == 200
        assert client.post(
            f"/api/v1/kyc/{session_id}/selfie",
            json={"liveness_passed": True, "face_match_score": 0.96},
        ).status_code == 200
        assert client.post(
            f"/api/v1/kyc/{session_id}/address",
            json={"address": "1 Demo Road, Bengaluru", "document_name": "bill.pdf"},
        ).status_code == 200
        submitted = client.post(
            f"/api/v1/kyc/{session_id}/submit",
            json={"pep_declared": False, "terms_accepted": True},
        )
        customer_response = client.get(
            f"/api/v1/admin/customers/{customer.id}"
        )

        assert submitted.status_code == 200
        assert customer_response.json()["kyc_status"] == "verified"
        assert customer_response.json()["application_status"] == "kyc_verified"
        assert client.post(
            f"/api/v1/kyc/{session_id}/submit",
            json={"pep_declared": False, "terms_accepted": True},
        ).status_code == 200
    finally:
        customer.kyc_status = original_kyc_status
        customer.application_status = original_application_status


def test_admin_card_limit_and_dispute_status_update_shared_domain_state() -> None:
    card = store.get_card("CARD-001")
    original_limit = card.daily_limit
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
        dispute.status = original_status


def test_pending_application_is_issued_after_kyc_and_lifecycle_is_validated() -> None:
    application = client.post(
        "/api/v1/cards/applications",
        json={"customer_id": "CUS-DEMO-003", "product": "GEMCARDS Classic"},
    )
    assert application.status_code == 201
    application_body = application.json()
    card_id = application_body["card_id"]
    assert application_body["status"] == "kyc_in_progress"
    assert client.get(f"/api/v1/cards/{card_id}").json()["status"] == "pending"
    assert client.post(
        f"/api/v1/cards/{card_id}/transition",
        json={"status": "active"},
    ).status_code == 409

    session = client.post(
        "/api/v1/kyc/session",
        json={
            "country": "India",
            "document_type": "National ID",
            "customer_id": "CUS-DEMO-003",
        },
    ).json()
    session_id = session["id"]
    incomplete_submission = client.post(
        f"/api/v1/kyc/{session_id}/submit",
        json={"pep_declared": False, "terms_accepted": True},
    )
    assert incomplete_submission.status_code == 409
    assert client.get(f"/api/v1/cards/{card_id}").json()["status"] == "pending"
    assert client.post(
        f"/api/v1/kyc/{session_id}/document",
        json={
            "name": "Jordan Lee",
            "dob": "1990-01-01",
            "id_number": "DEMO-3003",
        },
    ).status_code == 200
    assert client.post(
        f"/api/v1/kyc/{session_id}/selfie",
        json={"liveness_passed": True, "face_match_score": 0.96},
    ).status_code == 200
    assert client.post(
        f"/api/v1/kyc/{session_id}/address",
        json={"address": "1 Demo Road, Bengaluru", "document_name": "bill.pdf"},
    ).status_code == 200
    assert client.post(
        f"/api/v1/kyc/{session_id}/submit",
        json={"pep_declared": False, "terms_accepted": True},
    ).status_code == 200
    assert client.get(f"/api/v1/cards/{card_id}").json()["status"] == "active"
    assert client.get(
        f"/api/v1/cards/applications/{application_body['id']}"
    ).json()["status"] == "card_active"

    assert client.post(f"/api/v1/cards/{card_id}/freeze").json()["status"] == "frozen"
    assert client.post(f"/api/v1/cards/{card_id}/unfreeze").json()["status"] == "active"
    assert client.post(
        f"/api/v1/cards/{card_id}/transition",
        json={"status": "replaced"},
    ).json()["status"] == "replaced"
    assert client.post(
        f"/api/v1/cards/{card_id}/transition",
        json={"status": "closed"},
    ).json()["status"] == "closed"
    assert client.post(f"/api/v1/cards/{card_id}/unfreeze").status_code == 409


def test_card_controls_apply_all_supported_settings_and_audit_changes() -> None:
    card = store.get_card("CARD-001")
    original = card.model_copy(deep=True)
    try:
        response = client.patch(
            "/api/v1/cards/CARD-001/controls",
            json={
                "daily_limit": 40000,
                "international_enabled": True,
                "contactless_enabled": False,
                "online_enabled": False,
                "atm_enabled": False,
            },
        )
        assert response.status_code == 200
        assert response.json()["daily_limit"] == 40000
        assert response.json()["international_enabled"] is True
        assert response.json()["contactless_enabled"] is False
        assert response.json()["online_enabled"] is False
        assert response.json()["atm_enabled"] is False
        empty = client.patch("/api/v1/cards/CARD-001/controls", json={})
        assert empty.status_code == 422
        assert client.get("/api/v1/admin/audit").json()[0]["event_type"] == (
            "CARD_CONTROLS_UPDATED"
        )
    finally:
        card.daily_limit = original.daily_limit
        card.international_enabled = original.international_enabled
        card.contactless_enabled = original.contactless_enabled
        card.online_enabled = original.online_enabled
        card.atm_enabled = original.atm_enabled


def test_dispute_status_and_resolution_are_audited() -> None:
    created = client.post(
        "/api/v1/disputes",
        json={"transaction_id": "TXN-101", "reason": "Unknown purchase"},
    )
    dispute_id = created.json()["id"]
    investigating = client.post(
        f"/api/v1/disputes/{dispute_id}/status",
        json={"status": "investigating"},
    )
    resolved = client.post(
        f"/api/v1/disputes/{dispute_id}/status",
        json={"status": "resolved"},
    )
    invalid = client.post(
        f"/api/v1/disputes/{dispute_id}/status",
        json={"status": "open"},
    )

    assert created.status_code == 201
    assert investigating.json()["status"] == "investigating"
    assert resolved.json()["status"] == "resolved"
    assert invalid.status_code == 409
    event = next(
        item
        for item in client.get("/api/v1/admin/audit").json()
        if item["event_type"] == "DISPUTE_RESOLVED"
        and item["dispute_id"] == dispute_id
    )
    assert event["transaction_id"] == "TXN-101"


def test_analytics_and_audit_are_derived_from_domain_events() -> None:
    before = client.get("/api/v1/admin/analytics").json()
    decision = client.post(
        "/api/v1/transactions/simulate",
        json={
            "card_id": "CARD-003",
            "merchant": "Demo Foreign Electronics",
            "amount": 9800,
            "country": "SG",
            "channel": "ONLINE",
        },
    ).json()
    events = client.get("/api/v1/admin/audit").json()
    after = client.get("/api/v1/admin/metrics").json()
    transaction = next(
        item
        for item in client.get("/api/v1/transactions").json()
        if item["authorization_id"] == decision["authorization_id"]
    )

    assert decision["decision"] == "FLAGGED"
    assert transaction["currency"] == "INR"
    assert after["total_customers"] == len(store.customers)
    assert after["cards_issued"] == sum(
        card.status != "pending" for card in store.cards.values()
    )
    assert after["active_cards"] == sum(
        card.status == "active" for card in store.cards.values()
    )
    assert after["volume_series"][-1] == after["daily_transaction_volume"]
    assert (
        after["approved_count"]
        + after["declined_count"]
        + after["flagged_count"]
        == after["transactions_today"]
    )
    assert after["fraud_alerts"] == sum(
        alert.status == "open" for alert in store.fraud_alerts.values()
    )
    assert after["open_disputes"] == sum(
        dispute.status == "open" for dispute in store.disputes.values()
    )
    assert after["flagged_count"] >= before["flagged_count"]
    fraud_event = next(
        event
        for event in events
        if event["event_type"] == "FRAUD_ALERT_CREATED"
        and event["transaction_id"] == transaction["id"]
    )
    assert fraud_event["customer_id"] == store.get_card("CARD-003").customer_id
