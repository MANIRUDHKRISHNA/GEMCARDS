from datetime import datetime, timezone

from app.domain import store
from app.schemas.domain import (
    AuthorizationRequest,
    AuthorizationResponse,
    Card,
    FraudAlert,
    RuleResult,
    Transaction,
    TransactionDecision,
)




def is_foreign(country: str) -> bool:
    return country.strip().casefold() not in {"in", "india"}


def evaluate_authorization(
    card: Card,
    request: AuthorizationRequest,
) -> tuple[TransactionDecision, list[str], list[RuleResult]]:
    foreign = is_foreign(request.country)
    channel_enabled = {
        "ONLINE": card.online_enabled,
        "POS": card.contactless_enabled,
        "ATM": card.atm_enabled,
    }[request.channel]
    today = datetime.now(timezone.utc).date()
    spent_today = sum(
        transaction.amount
        for transaction in store.transactions.values()
        if transaction.card_id == card.id
        and transaction.decision == "APPROVED"
        and datetime.fromisoformat(
            transaction.occurred_at.replace("Z", "+00:00")
        ).date()
        == today
    )
    available_limit = max(card.daily_limit - spent_today, 0)
    threshold_exceeded = (
        foreign and request.amount >= store.FRAUD_REVIEW_THRESHOLD
    )

    results = [
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
            passed=request.amount <= available_limit,
            detail=(
                "Amount is within the remaining daily limit"
                if request.amount <= available_limit
                else "Amount exceeds the daily limit"
            ),
        ),
        RuleResult(
            rule="Channel controls",
            passed=channel_enabled,
            detail=(
                "Channel is enabled"
                if channel_enabled
                else f"{request.channel} transactions are disabled"
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
        RuleResult(
            rule="High-value foreign activity",
            passed=not threshold_exceeded,
            detail=(
                "High-value foreign activity flagged for review"
                if threshold_exceeded
                else "No high-value foreign activity pattern"
            ),
        ),
    ]
    reasons = [result.detail for result in results if not result.passed]
    hard_decline = any(
        not result.passed
        for result in results
        if result.rule != "High-value foreign activity"
    )
    decision = (
        "DECLINED"
        if hard_decline
        else "FLAGGED"
        if threshold_exceeded
        else "APPROVED"
    )
    return decision, reasons, results


def execute_authorization(
    request: AuthorizationRequest,
) -> AuthorizationResponse:
    card = store.get_card(request.card_id)
    decision, reasons, rule_results = evaluate_authorization(card, request)
    authorization_id = f"AUTH-DEMO-{store.next_sequence('authorization'):04d}"
    transaction_id = f"TXN-{store.next_sequence('transaction'):03d}"
    occurred_at = store.now_iso()
    transaction = Transaction(
        id=transaction_id,
        authorization_id=authorization_id,
        card_id=card.id,
        merchant=request.merchant,
        amount=request.amount,
        currency=request.currency.upper(),
        country=request.country.strip().upper(),
        channel=request.channel,
        decision=decision,
        occurred_at=occurred_at,
        reasons=reasons,
    )
    store.transactions[transaction.id] = transaction
    store.save_entity("transactions", transaction)
    store.record_audit_event(
        f"TRANSACTION_{decision}",
        customer_id=card.customer_id,
        card_id=card.id,
        transaction_id=transaction.id,
        details={"amount": transaction.amount, "currency": transaction.currency},
        timestamp=occurred_at,
    )

    if is_foreign(request.country) and request.amount >= store.FRAUD_REVIEW_THRESHOLD:
        alert_id = f"FRA-DEMO-{store.next_sequence('fraud_alert'):03d}"
        severity = "high" if request.amount >= 15000 else "medium"
        alert = FraudAlert(
            id=alert_id,
            transaction_id=transaction.id,
            customer_id=card.customer_id,
            merchant=request.merchant,
            amount=request.amount,
            country=transaction.country,
            severity=severity,
            reason="High-value foreign transaction needs review",
            created_at=occurred_at,
        )
        store.fraud_alerts[alert.id] = alert
        store.save_entity("fraud_alerts", alert)
        store.record_audit_event(
            "FRAUD_ALERT_CREATED",
            customer_id=card.customer_id,
            card_id=card.id,
            transaction_id=transaction.id,
            details={"alert_id": alert.id, "severity": alert.severity},
            timestamp=occurred_at,
        )

    return AuthorizationResponse(
        decision=decision,
        authorization_id=authorization_id,
        reasons=reasons,
        rule_results=rule_results,
    )
