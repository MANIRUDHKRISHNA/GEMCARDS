from datetime import datetime, timezone

from fastapi import HTTPException

from app.schemas.domain import (
    AuditEvent,
    Card,
    CardApplication,
    CardStatus,
    Customer,
    Dispute,
    DisputeStatus,
    FraudAlert,
    RewardSummary,
    Transaction,
)

DEMO_CUSTOMER_ID = "CUS-DEMO-001"
FRAUD_REVIEW_THRESHOLD = 7500

customers: dict[str, Customer] = {
    DEMO_CUSTOMER_ID: Customer(
        id=DEMO_CUSTOMER_ID,
        name="Alex Morgan",
        email="alex.morgan@example.demo",
        kyc_status="verified",
        member_since="2026-10-01",
        application_status="card_active",
    ),
    "CUS-DEMO-002": Customer(
        id="CUS-DEMO-002",
        name="Priya Shah",
        email="priya.shah@example.demo",
        kyc_status="under_review",
        member_since="2026-10-03",
        application_status="kyc_in_progress",
    ),
    "CUS-DEMO-003": Customer(
        id="CUS-DEMO-003",
        name="Jordan Lee",
        email="jordan.lee@example.demo",
        kyc_status="pending",
        member_since="2026-10-05",
        application_status="draft",
    ),
}

available_balances: dict[str, float] = {
    DEMO_CUSTOMER_ID: 24680.00,
    "CUS-DEMO-002": 18450.00,
    "CUS-DEMO-003": 0.00,
}

cards: dict[str, Card] = {
    "CARD-001": Card(
        id="CARD-001",
        customer_id=DEMO_CUSTOMER_ID,
        product="GEMCARDS Platinum",
        card_type="physical",
        network="Visa",
        masked_number="•••• 4821",
        expiry="09/30",
        status="active",
        daily_limit=50000,
        international_enabled=False,
        contactless_enabled=True,
        online_enabled=True,
        atm_enabled=True,
    ),
    "CARD-V01": Card(
        id="CARD-V01",
        customer_id=DEMO_CUSTOMER_ID,
        product="GEM Virtual",
        card_type="virtual",
        network="Visa",
        masked_number="•••• 9104",
        expiry="09/30",
        status="active",
        daily_limit=25000,
        international_enabled=False,
        contactless_enabled=False,
        online_enabled=True,
        atm_enabled=False,
    ),
    "CARD-002": Card(
        id="CARD-002",
        customer_id="CUS-DEMO-002",
        product="GEMCARDS Classic",
        card_type="physical",
        network="RuPay",
        masked_number="•••• 7730",
        expiry="10/30",
        status="frozen",
        daily_limit=30000,
        international_enabled=True,
        contactless_enabled=True,
        online_enabled=True,
        atm_enabled=True,
    ),
    "CARD-003": Card(
        id="CARD-003",
        customer_id=DEMO_CUSTOMER_ID,
        product="GEM Travel",
        card_type="physical",
        network="Visa",
        masked_number="•••• 6628",
        expiry="09/30",
        status="active",
        daily_limit=100000,
        international_enabled=True,
        contactless_enabled=True,
        online_enabled=True,
        atm_enabled=True,
    ),
}

transactions: dict[str, Transaction] = {
    "TXN-101": Transaction(
        id="TXN-101",
        authorization_id="AUTH-SEED-101",
        card_id="CARD-001",
        merchant="Metro Mart",
        amount=1240,
        country="IN",
        channel="POS",
        decision="APPROVED",
        occurred_at="2026-10-09T10:42:00Z",
    ),
    "TXN-102": Transaction(
        id="TXN-102",
        authorization_id="AUTH-SEED-102",
        card_id="CARD-V01",
        merchant="CloudStream",
        amount=299,
        country="IN",
        channel="ONLINE",
        decision="APPROVED",
        occurred_at="2026-10-08T20:11:00Z",
    ),
    "TXN-103": Transaction(
        id="TXN-103",
        authorization_id="AUTH-SEED-103",
        card_id="CARD-003",
        merchant="Northstar Electronics",
        amount=9800,
        country="SG",
        channel="ONLINE",
        decision="FLAGGED",
        occurred_at="2026-10-09T08:16:00Z",
        reasons=["High-value transaction from a foreign location"],
    ),
}

fraud_alerts: dict[str, FraudAlert] = {
    "FRA-01": FraudAlert(
        id="FRA-01",
        transaction_id="TXN-103",
        customer_id=DEMO_CUSTOMER_ID,
        merchant="Northstar Electronics",
        amount=9800,
        country="SG",
        severity="high",
        reason="High-value foreign transaction needs review",
        created_at="2026-10-09T08:16:00Z",
    )
}

disputes: dict[str, Dispute] = {
    "DSP-01": Dispute(
        id="DSP-01",
        transaction_id="TXN-101",
        customer_id=DEMO_CUSTOMER_ID,
        reason="Merchant recognition",
        details="Demo dispute awaiting operations review",
        created_at="2026-10-09T12:00:00Z",
    )
}

card_applications: dict[str, CardApplication] = {}
audit_events: list[AuditEvent] = []
_audit_sequence = 0
_application_sequence = 0

CARD_TRANSITIONS: dict[CardStatus, set[CardStatus]] = {
    "pending": {"active"},
    "active": {"frozen", "replaced"},
    "frozen": {"active"},
    "replaced": {"closed"},
    "closed": set(),
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def record_audit_event(
    event_type: str,
    *,
    customer_id: str | None = None,
    card_id: str | None = None,
    transaction_id: str | None = None,
    dispute_id: str | None = None,
    details: dict[str, str | int | float | bool | None] | None = None,
    timestamp: str | None = None,
) -> AuditEvent:
    global _audit_sequence
    _audit_sequence += 1
    event = AuditEvent(
        id=f"AUD-{_audit_sequence:06d}",
        event_type=event_type,
        timestamp=timestamp or now_iso(),
        customer_id=customer_id,
        card_id=card_id,
        transaction_id=transaction_id,
        dispute_id=dispute_id,
        details=details or {},
    )
    audit_events.append(event)
    return event


def transition_card(card_id: str, target_status: CardStatus) -> Card:
    card = get_card(card_id)
    if target_status not in CARD_TRANSITIONS[card.status]:
        raise ValueError(f"Cannot transition card from {card.status} to {target_status}")
    previous_status = card.status
    customer = get_customer(card.customer_id)
    if previous_status == "pending" and customer.kyc_status != "verified":
        raise ValueError("Pending cards require verified KYC before activation")
    card.status = target_status
    event_type = {
        "active": "CARD_ISSUED" if previous_status == "pending" else "CARD_UNFROZEN",
        "frozen": "CARD_FROZEN",
        "replaced": "CARD_REPLACED",
        "closed": "CARD_CLOSED",
    }[target_status]
    record_audit_event(
        event_type,
        customer_id=card.customer_id,
        card_id=card.id,
        details={"previous_status": previous_status, "status": target_status},
    )
    if previous_status == "pending" and target_status == "active":
        for application in card_applications.values():
            if application.card_id == card.id:
                application.status = "card_active"
                customer.application_status = "card_active"
    return card


def create_card_application(customer_id: str, product: str) -> CardApplication:
    global _application_sequence
    customer = get_customer(customer_id)
    if any(
        application.customer_id == customer.id
        and application.status in {"kyc_in_progress", "kyc_verified", "card_pending"}
        for application in card_applications.values()
    ):
        raise HTTPException(
            status_code=409,
            detail="This customer already has an application in progress",
        )
    _application_sequence += 1
    while (
        f"APP-{_application_sequence:04d}" in card_applications
        or f"CARD-P{_application_sequence:03d}" in cards
    ):
        _application_sequence += 1
    application_id = f"APP-{_application_sequence:04d}"
    card_id = f"CARD-P{_application_sequence:03d}"
    card = Card(
        id=card_id,
        customer_id=customer.id,
        product=product,
        card_type="physical",
        network="Visa",
        masked_number=f"•••• {(_application_sequence + 7200) % 10000:04d}",
        expiry="09/30",
        status="pending",
        daily_limit=50000,
        international_enabled=False,
        contactless_enabled=True,
        online_enabled=True,
        atm_enabled=True,
    )
    application_status = (
        "card_pending" if customer.kyc_status == "verified" else "kyc_in_progress"
    )
    application = CardApplication(
        id=application_id,
        customer_id=customer.id,
        card_id=card.id,
        status=application_status,
        created_at=now_iso(),
    )
    cards[card.id] = card
    card_applications[application.id] = application
    customer.application_status = application_status
    record_audit_event(
        "CARD_APPLICATION_CREATED",
        customer_id=customer.id,
        card_id=card.id,
        details={"application_id": application.id, "status": application_status},
    )
    return application


def get_rewards(customer_id: str) -> RewardSummary:
    get_customer(customer_id)
    card_ids = {
        card.id for card in cards.values() if card.customer_id == customer_id
    }
    eligible_spend = sum(
        transaction.amount
        for transaction in transactions.values()
        if transaction.card_id in card_ids and transaction.decision == "APPROVED"
    )
    points = int(eligible_spend // 10)
    return RewardSummary(
        customer_id=customer_id,
        points=points,
        available_value=round(points / 10, 2),
    )


def complete_customer_kyc(customer_id: str) -> Customer:
    customer = get_customer(customer_id)
    customer.kyc_status = "verified"
    record_audit_event("KYC_VERIFIED", customer_id=customer.id)
    for application in card_applications.values():
        if application.customer_id == customer.id and application.status == "kyc_in_progress":
            application.status = "kyc_verified"
            customer.application_status = "kyc_verified"
            application.status = "card_pending"
            customer.application_status = "card_pending"
            record_audit_event(
                "CARD_APPLICATION_STATUS_CHANGED",
                customer_id=customer.id,
                card_id=application.card_id,
                details={"application_id": application.id, "status": "card_pending"},
            )
            transition_card(application.card_id, "active")
            application.status = "card_active"
            customer.application_status = "card_active"
            return customer
    customer.application_status = (
        "card_active"
        if any(
            card.customer_id == customer.id and card.status == "active"
            for card in cards.values()
        )
        else "kyc_verified"
    )
    return customer


def resolve_fraud_alert(alert_id: str) -> FraudAlert:
    alert = fraud_alerts.get(alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Fraud alert not found")
    if alert.status == "open":
        alert.status = "resolved"
        alert.resolved_at = now_iso()
        record_audit_event(
            "FRAUD_ALERT_RESOLVED",
            customer_id=alert.customer_id,
            transaction_id=alert.transaction_id,
            details={"alert_id": alert.id},
            timestamp=alert.resolved_at,
        )
    return alert


def transition_dispute(dispute_id: str, target_status: DisputeStatus) -> Dispute:
    dispute = disputes.get(dispute_id)
    if dispute is None:
        raise HTTPException(status_code=404, detail="Dispute not found")
    allowed = {
        "open": {"investigating", "resolved"},
        "investigating": {"resolved"},
        "resolved": set(),
    }
    if target_status == dispute.status:
        return dispute
    if target_status not in allowed[dispute.status]:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot transition dispute from {dispute.status} to {target_status}",
        )
    dispute.status = target_status
    if target_status == "resolved":
        record_audit_event(
            "DISPUTE_RESOLVED",
            customer_id=dispute.customer_id,
            transaction_id=dispute.transaction_id,
            dispute_id=dispute.id,
        )
    return dispute


def get_card(card_id: str) -> Card:
    card = cards.get(card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Card not found")
    return card


def get_transaction(transaction_id: str) -> Transaction:
    transaction = transactions.get(transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


def get_customer(customer_id: str) -> Customer:
    customer = customers.get(customer_id)
    if customer is None:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer
