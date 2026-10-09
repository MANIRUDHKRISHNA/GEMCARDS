from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.domain import store
from app.schemas.domain import Dispute, DisputeCreate, DisputeStatus

router = APIRouter(prefix="/api/v1/disputes", tags=["disputes"])


class DisputeStatusUpdate(BaseModel):
    status: DisputeStatus


@router.get("", response_model=list[Dispute])
def list_disputes(
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> list[Dispute]:
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    store.get_customer(selected_customer_id)
    return [
        dispute for dispute in store.disputes.values()
        if dispute.customer_id == selected_customer_id
    ]


@router.post("/{dispute_id}/status", response_model=Dispute)
def update_dispute_status(
    dispute_id: str,
    payload: DisputeStatusUpdate,
) -> Dispute:
    return store.transition_dispute(dispute_id, payload.status)


@router.post("", response_model=Dispute, status_code=201)
def create_dispute(
    payload: DisputeCreate,
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> Dispute:
    transaction = store.get_transaction(payload.transaction_id)
    card = store.get_card(transaction.card_id)
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    store.get_customer(selected_customer_id)
    if card.customer_id != selected_customer_id:
        raise HTTPException(status_code=404, detail="Transaction not found")
    if transaction.decision == "DECLINED":
        raise HTTPException(
            status_code=409,
            detail="A declined transaction cannot be disputed in this demo",
        )
    sequence = store.next_sequence("dispute")
    dispute = Dispute(
        id=f"DSP-DEMO-{sequence:03d}",
        transaction_id=transaction.id,
        customer_id=card.customer_id,
        reason=payload.reason,
        details=payload.details,
        created_at=store.now_iso(),
    )
    store.disputes[dispute.id] = dispute
    store.save_entity("disputes", dispute)
    store.record_audit_event(
        "DISPUTE_OPENED",
        customer_id=dispute.customer_id,
        transaction_id=dispute.transaction_id,
        dispute_id=dispute.id,
    )
    return dispute
