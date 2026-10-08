from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.domain import store
from app.schemas.domain import Dispute, DisputeCreate

router = APIRouter(prefix="/api/v1/disputes", tags=["disputes"])
_dispute_sequence = 1


class DisputeStatusUpdate(BaseModel):
    status: Literal["open", "investigating", "resolved"]


@router.get("", response_model=list[Dispute])
def list_disputes() -> list[Dispute]:
    return list(store.disputes.values())


@router.post("/{dispute_id}/status", response_model=Dispute)
def update_dispute_status(
    dispute_id: str,
    payload: DisputeStatusUpdate,
) -> Dispute:
    dispute = store.disputes.get(dispute_id)
    if dispute is None:
        raise HTTPException(status_code=404, detail="Dispute not found")
    dispute.status = payload.status
    return dispute


@router.post("", response_model=Dispute, status_code=201)
def create_dispute(payload: DisputeCreate) -> Dispute:
    global _dispute_sequence
    transaction = store.get_transaction(payload.transaction_id)
    card = store.get_card(transaction.card_id)
    if transaction.decision == "DECLINED":
        raise HTTPException(
            status_code=409,
            detail="A declined transaction cannot be disputed in this demo",
        )
    _dispute_sequence += 1
    dispute = Dispute(
        id=f"DSP-DEMO-{_dispute_sequence:03d}",
        transaction_id=transaction.id,
        customer_id=card.customer_id,
        reason=payload.reason,
        details=payload.details,
        created_at=store.now_iso(),
    )
    store.disputes[dispute.id] = dispute
    return dispute
