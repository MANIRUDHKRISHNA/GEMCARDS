from fastapi import APIRouter

from app.domain import store
from app.schemas.domain import Customer, CustomerDashboard

router = APIRouter(prefix="/api/v1/customer", tags=["customer"])


@router.get("/me", response_model=Customer)
def customer_me() -> Customer:
    return store.get_customer(store.DEMO_CUSTOMER_ID)


@router.get("/dashboard", response_model=CustomerDashboard)
def customer_dashboard() -> CustomerDashboard:
    customer_id = store.DEMO_CUSTOMER_ID
    return CustomerDashboard(
        customer=store.get_customer(customer_id),
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
        rewards=store.rewards[customer_id],
    )
