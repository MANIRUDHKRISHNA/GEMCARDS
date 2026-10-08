from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.domain import store
from app.domain.authorization import execute_authorization
from app.schemas.domain import (
    AuthorizationRequest,
    AuditEvent,
    Card,
    CardStatus,
    Dispute,
    DisputeStatus,
    FraudAlert,
    Transaction,
)

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])


class Simulation(BaseModel):
    card_id: str
    merchant: str = Field(min_length=1, max_length=80)
    amount: float = Field(gt=0)
    country: str = Field(min_length=2, max_length=80)
    transaction_type: Literal["purchase", "atm", "online"] = "purchase"


class LimitUpdate(BaseModel):
    limit: int = Field(ge=1000, le=250000)


class StatusUpdate(BaseModel):
    status: DisputeStatus


def _customer_data(customer_id: str) -> dict:
    customer = store.get_customer(customer_id)
    customer_cards = [
        card for card in store.cards.values() if card.customer_id == customer_id
    ]
    customer_transactions = [
        transaction
        for transaction in store.transactions.values()
        if transaction.card_id in {card.id for card in customer_cards}
    ]
    open_alerts = [
        alert
        for alert in store.fraud_alerts.values()
        if alert.customer_id == customer_id and alert.status == "open"
    ]
    risk = (
        "high"
        if any(alert.severity == "high" for alert in open_alerts)
        else "medium"
        if open_alerts
        else customer.risk_state
    )
    return {
        "id": customer.id,
        "name": customer.name,
        "email": customer.email,
        "kyc_status": customer.kyc_status,
        "member_since": customer.member_since,
        "application_status": customer.application_status,
        "cards": len(customer_cards),
        "card_count": len(customer_cards),
        "transactions": len(customer_transactions),
        "risk": risk,
        "risk_state": risk,
    }


def _card_data(card: Card) -> dict:
    customer = store.get_customer(card.customer_id)
    return {
        **card.model_dump(),
        "customer": customer.name,
        "type": card.card_type,
        "issued_at": customer.member_since,
        "limit": card.daily_limit,
    }


def _transaction_data(transaction: Transaction) -> dict:
    card = store.get_card(transaction.card_id)
    return {
        **transaction.model_dump(),
        "customer": store.get_customer(card.customer_id).name,
        "card": card.masked_number,
        "status": transaction.decision.lower(),
        "risk_score": {
            "APPROVED": 8,
            "DECLINED": 55,
            "FLAGGED": 91,
        }[transaction.decision],
        "timestamp": transaction.occurred_at,
    }


def _metrics() -> dict:
    today = datetime.now(timezone.utc).date()
    transactions = list(store.transactions.values())
    today_transactions = [
        transaction
        for transaction in transactions
        if datetime.fromisoformat(
            transaction.occurred_at.replace("Z", "+00:00")
        ).date()
        == today
    ]
    issued_events = [
        event
        for event in store.audit_events
        if event.event_type == "CARD_ISSUED"
    ]
    cards_issued = sum(card.status != "pending" for card in store.cards.values())
    day_buckets = [today - timedelta(days=offset) for offset in reversed(range(7))]
    volume_series = [
        sum(
            transaction.amount
            for transaction in transactions
            if transaction.decision == "APPROVED"
            and datetime.fromisoformat(
                transaction.occurred_at.replace("Z", "+00:00")
            ).date()
            == day
        )
        for day in day_buckets
    ]
    issuance_series = [
        sum(event.timestamp[:10] == day.isoformat() for event in issued_events)
        for day in day_buckets
    ]
    decisions = [transaction.decision for transaction in today_transactions]

    return {
        "total_customers": len(store.customers),
        "active_cards": sum(card.status == "active" for card in store.cards.values()),
        "cards_issued": cards_issued,
        "transactions_today": len(today_transactions),
        "transaction_volume": sum(
            item.amount
            for item in today_transactions
            if item.decision == "APPROVED"
        ),
        "daily_transaction_volume": sum(
            item.amount
            for item in today_transactions
            if item.decision == "APPROVED"
        ),
        "approved_count": decisions.count("APPROVED"),
        "declined_count": decisions.count("DECLINED"),
        "flagged_count": decisions.count("FLAGGED"),
        "pending_kyc": sum(
            customer.kyc_status != "verified" for customer in store.customers.values()
        ),
        "fraud_alerts": sum(
            alert.status == "open" for alert in store.fraud_alerts.values()
        ),
        "open_disputes": sum(
            dispute.status == "open" for dispute in store.disputes.values()
        ),
        "cards_issued_today": sum(
            event.timestamp[:10] == today.isoformat() for event in issued_events
        ),
        "volume_series": volume_series,
        "issuance_series": issuance_series,
    }


@router.get("/metrics")
def metrics() -> dict:
    return _metrics()


@router.get("/analytics")
def analytics() -> dict:
    return _metrics()


@router.get("/audit", response_model=list[AuditEvent])
def audit_events() -> list[AuditEvent]:
    return list(reversed(store.audit_events))


@router.get("/customers")
def customers(query: str = "", kyc_status: str = "") -> list[dict]:
    needle = query.casefold()
    results = [_customer_data(customer_id) for customer_id in store.customers]
    return [
        customer
        for customer in results
        if (
            not needle
            or needle in customer["name"].casefold()
            or needle in customer["id"].casefold()
            or needle in customer["email"].casefold()
        )
        and (not kyc_status or customer["kyc_status"] == kyc_status)
    ]


@router.get("/customers/{customer_id}")
def customer_detail(customer_id: str) -> dict:
    customer = _customer_data(customer_id)
    customer_cards = [
        _card_data(card)
        for card in store.cards.values()
        if card.customer_id == customer_id
    ]
    card_ids = {card["id"] for card in customer_cards}
    customer_transactions = [
        _transaction_data(transaction)
        for transaction in store.transactions.values()
        if transaction.card_id in card_ids
    ]
    return {
        **customer,
        "cards_detail": customer_cards,
        "transactions_detail": customer_transactions,
        "disputes": [
            dispute.model_dump()
            for dispute in store.disputes.values()
            if dispute.customer_id == customer_id
        ],
    }


@router.get("/cards")
def cards(status: str = "") -> list[dict]:
    return [
        _card_data(card)
        for card in store.cards.values()
        if not status or card.status == status
    ]


@router.get("/cards/{card_id}")
def card_detail(card_id: str) -> dict:
    return _card_data(store.get_card(card_id))


def _admin_card_transition(card_id: str, target: CardStatus) -> dict:
    try:
        return _card_data(store.transition_card(card_id, target))
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.post("/cards/{card_id}/freeze")
def freeze(card_id: str) -> dict:
    return _admin_card_transition(card_id, "frozen")


@router.post("/cards/{card_id}/unfreeze")
def unfreeze(card_id: str) -> dict:
    return _admin_card_transition(card_id, "active")


@router.post("/cards/{card_id}/limit")
def update_limit(card_id: str, payload: LimitUpdate) -> dict:
    card = store.get_card(card_id)
    card.daily_limit = payload.limit
    store.record_audit_event(
        "CARD_LIMIT_UPDATED",
        customer_id=card.customer_id,
        card_id=card.id,
        details={"daily_limit": payload.limit},
    )
    return _card_data(card)


@router.post("/cards/{card_id}/replace")
def replace(card_id: str) -> dict:
    card = _admin_card_transition(card_id, "replaced")
    return {"card": card, "message": "Demo replacement requested"}


@router.get("/transactions")
def transactions(status: str = "") -> list[dict]:
    return [
        _transaction_data(transaction)
        for transaction in store.transactions.values()
        if not status or transaction.decision.casefold() == status.casefold()
    ]


@router.post("/transactions/simulate")
def simulate(payload: Simulation) -> dict:
    channel = {
        "purchase": "POS",
        "atm": "ATM",
        "online": "ONLINE",
    }[payload.transaction_type]
    response = execute_authorization(
        AuthorizationRequest(
            card_id=payload.card_id,
            merchant=payload.merchant,
            amount=payload.amount,
            country=payload.country,
            channel=channel,
        )
    )
    return {
        "decision": response.decision,
        "authorization_id": response.authorization_id,
        "rules": [
            {
                "name": result.rule,
                "passed": result.passed,
                "explanation": result.detail,
            }
            for result in response.rule_results
        ],
        "explanation": "; ".join(response.reasons)
        if response.reasons
        else "Deterministic demo rules completed.",
    }


@router.get("/fraud", response_model=list[FraudAlert])
def fraud() -> list[FraudAlert]:
    return list(store.fraud_alerts.values())


@router.post("/fraud/{alert_id}/resolve")
def resolve_fraud(alert_id: str, payload: StatusUpdate) -> FraudAlert:
    if payload.status != "resolved":
        raise HTTPException(status_code=422, detail="Fraud alerts can only be resolved")
    return store.resolve_fraud_alert(alert_id)


@router.get("/disputes", response_model=list[Dispute])
def disputes() -> list[Dispute]:
    return list(store.disputes.values())


@router.post("/disputes/{dispute_id}/status")
def update_dispute(dispute_id: str, payload: StatusUpdate) -> Dispute:
    return store.transition_dispute(dispute_id, payload.status)
