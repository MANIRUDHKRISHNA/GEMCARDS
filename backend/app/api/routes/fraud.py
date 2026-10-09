from fastapi import APIRouter, Query

from app.domain import store
from app.schemas.domain import FraudAlert

router = APIRouter(prefix="/api/v1/fraud", tags=["fraud"])


@router.get("", response_model=list[FraudAlert])
def list_fraud_alerts(
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> list[FraudAlert]:
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    store.get_customer(selected_customer_id)
    return [
        alert for alert in store.fraud_alerts.values()
        if alert.customer_id == selected_customer_id
    ]


@router.post("/{alert_id}/resolve", response_model=FraudAlert)
def resolve_fraud_alert(alert_id: str) -> FraudAlert:
    return store.resolve_fraud_alert(alert_id)
