from datetime import datetime, timezone

from fastapi import HTTPException

from app.schemas.domain import Card, Customer, Dispute, FraudAlert, RewardSummary, Transaction

DEMO_CUSTOMER_ID = "CUS-DEMO-001"
FRAUD_REVIEW_THRESHOLD = 7500

customers: dict[str, Customer] = {
    DEMO_CUSTOMER_ID: Customer(
        id=DEMO_CUSTOMER_ID,
        name="Alex Morgan",
        email="alex.morgan@example.demo",
        kyc_status="verified",
        member_since="2026-10-01",
    ),
    "CUS-DEMO-002": Customer(
        id="CUS-DEMO-002",
        name="Priya Shah",
        email="priya.shah@example.demo",
        kyc_status="under_review",
        member_since="2026-10-03",
    ),
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

rewards: dict[str, RewardSummary] = {
    DEMO_CUSTOMER_ID: RewardSummary(
        customer_id=DEMO_CUSTOMER_ID,
        points=1240,
        available_value=124,
    ),
    "CUS-DEMO-002": RewardSummary(
        customer_id="CUS-DEMO-002",
        points=640,
        available_value=64,
    ),
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


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
