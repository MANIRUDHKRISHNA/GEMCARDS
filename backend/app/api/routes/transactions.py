from fastapi import APIRouter, HTTPException

from app.domain import store
from app.schemas.domain import (
    AuthorizationRequest,
    AuthorizationResponse,
    FraudAlert,
    RuleResult,
    Transaction,
)

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])

_authorization_sequence = 0
_transaction_sequence = 103
_fraud_sequence = 1


def _is_foreign(country: str) -> bool:
    return country.strip().casefold() not in {"in", "india"}


@router.get("", response_model=list[Transaction])
def list_transactions() -> list[Transaction]:
    return sorted(
        store.transactions.values(),
        key=lambda transaction: transaction.occurred_at,
        reverse=True,
    )


@router.get("/{transaction_id}", response_model=Transaction)
def transaction_detail(transaction_id: str) -> Transaction:
    return store.get_transaction(transaction_id)


@router.post("/simulate", response_model=AuthorizationResponse)
def simulate_authorization(payload: AuthorizationRequest) -> AuthorizationResponse:
    global _authorization_sequence, _transaction_sequence, _fraud_sequence

    card = store.get_card(payload.card_id)
    foreign = _is_foreign(payload.country)
    channel_enabled = (
        card.online_enabled
        if payload.channel == "ONLINE"
        else card.atm_enabled
        if payload.channel == "ATM"
        else True
    )
    rule_results = [
        RuleResult(
            rule="Card status",
            passed=card.status == "active",
            detail=(
                "Card is active"
                if card.status == "active"
                else f"Card is {card.status}"
            ),
        ),
        RuleResult(
            rule="Daily limit",
            passed=payload.amount <= card.daily_limit,
            detail=(
                "Amount is within the daily limit"
                if payload.amount <= card.daily_limit
                else "Amount exceeds the daily limit"
            ),
        ),
        RuleResult(
            rule="Channel controls",
            passed=channel_enabled,
            detail=(
                "Channel is enabled"
                if channel_enabled
                else f"{payload.channel} transactions are disabled"
            ),
        ),
        RuleResult(
            rule="International usage",
            passed=not foreign or card.international_enabled,
            detail=(
                "Location is permitted"
                if not foreign or card.international_enabled
                else "International usage is disabled"
            ),
        ),
    ]

    reasons = [result.detail for result in rule_results if not result.passed]
    hard_decline = bool(reasons)
    suspicious_foreign = foreign and payload.amount >= store.FRAUD_REVIEW_THRESHOLD
    rule_results.append(
        RuleResult(
            rule="High-value foreign activity",
            passed=not suspicious_foreign,
            detail=(
                "High-value foreign activity flagged for review"
                if suspicious_foreign
                else "No high-value foreign activity pattern"
            ),
        )
    )
    if suspicious_foreign:
        reasons.append("High-value transaction from a foreign location")

    decision = (
        "DECLINED"
        if hard_decline
        else "FLAGGED"
        if suspicious_foreign
        else "APPROVED"
    )
    _authorization_sequence += 1
    _transaction_sequence += 1
    authorization_id = f"AUTH-DEMO-{_authorization_sequence:04d}"
    transaction_id = f"TXN-{_transaction_sequence:03d}"
    transaction = Transaction(
        id=transaction_id,
        authorization_id=authorization_id,
        card_id=card.id,
        merchant=payload.merchant,
        amount=payload.amount,
        country=payload.country.strip().upper(),
        channel=payload.channel,
        decision=decision,
        occurred_at=store.now_iso(),
        reasons=reasons,
    )
    store.transactions[transaction_id] = transaction

    if decision == "FLAGGED":
        _fraud_sequence += 1
        alert_id = f"FRA-DEMO-{_fraud_sequence:03d}"
        store.fraud_alerts[alert_id] = FraudAlert(
            id=alert_id,
            transaction_id=transaction.id,
            customer_id=card.customer_id,
            merchant=payload.merchant,
            amount=payload.amount,
            country=payload.country.strip().upper(),
            severity="high",
            reason="High-value foreign transaction needs review",
            created_at=transaction.occurred_at,
        )

    return AuthorizationResponse(
        decision=decision,
        authorization_id=authorization_id,
        reasons=reasons,
        rule_results=rule_results,
    )
