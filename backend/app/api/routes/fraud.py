from fastapi import APIRouter, HTTPException

from app.domain import store
from app.schemas.domain import FraudAlert

router = APIRouter(prefix="/api/v1/fraud", tags=["fraud"])


@router.get("", response_model=list[FraudAlert])
def list_fraud_alerts() -> list[FraudAlert]:
    return list(store.fraud_alerts.values())


@router.post("/{alert_id}/resolve", response_model=FraudAlert)
def resolve_fraud_alert(alert_id: str) -> FraudAlert:
    alert = store.fraud_alerts.get(alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Fraud alert not found")
    alert.status = "resolved"
    alert.resolved_at = store.now_iso()
    return alert
