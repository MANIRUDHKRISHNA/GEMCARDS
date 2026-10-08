from fastapi import APIRouter

from app.domain import store
from app.schemas.domain import Customer, CustomerDashboard

router = APIRouter(prefix="/api/v1/customer", tags=["customer"])


def _customer_summary(customer_id: str) -> Customer:
    customer = store.get_customer(customer_id)
    cards = [
        card for card in store.cards.values() if card.customer_id == customer_id
    ]
    alerts = [
        alert
        for alert in store.fraud_alerts.values()
        if alert.customer_id == customer_id and alert.status == "open"
    ]
    risk_state = (
        "high"
        if any(alert.severity == "high" for alert in alerts)
        else "medium"
        if alerts
        else customer.risk_state
    )
    return customer.model_copy(
        update={"card_count": len(cards), "risk_state": risk_state}
    )


@router.get("/me", response_model=Customer)
def customer_me() -> Customer:
    return _customer_summary(store.DEMO_CUSTOMER_ID)


@router.get("/dashboard", response_model=CustomerDashboard)
def customer_dashboard() -> CustomerDashboard:
    customer_id = store.DEMO_CUSTOMER_ID
    return CustomerDashboard(
        customer=_customer_summary(customer_id),
        available_balance=store.available_balances[customer_id],
        cards=[card for card in store.cards.values() if card.customer_id == customer_id],
        recent_transactions=sorted(
            (
                transaction
                for transaction in store.transactions.values()
                if store.cards[transaction.card_id].customer_id == customer_id
            ),
            key=lambda transaction: transaction.occurred_at,
            reverse=True,
        )[:5],
        open_fraud_alerts=[
            alert
            for alert in store.fraud_alerts.values()
            if alert.customer_id == customer_id and alert.status == "open"
        ],
        rewards=store.get_rewards(customer_id),
    )
