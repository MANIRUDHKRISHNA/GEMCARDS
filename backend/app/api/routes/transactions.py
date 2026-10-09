from fastapi import APIRouter, HTTPException, Query

from app.domain import store
from app.domain.authorization import execute_authorization
from app.schemas.domain import (
    AuthorizationRequest,
    AuthorizationResponse,
    Transaction,
)

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])


@router.get("", response_model=list[Transaction])
def list_transactions(
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> list[Transaction]:
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    store.get_customer(selected_customer_id)
    return sorted(
        (
            transaction
            for transaction in store.transactions.values()
            if store.cards[transaction.card_id].customer_id == selected_customer_id
        ),
        key=lambda transaction: transaction.occurred_at,
        reverse=True,
    )


@router.get("/{transaction_id}", response_model=Transaction)
def transaction_detail(
    transaction_id: str,
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> Transaction:
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    transaction = store.get_transaction(transaction_id)
    if store.get_card(transaction.card_id).customer_id != selected_customer_id:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.post("/simulate", response_model=AuthorizationResponse)
def simulate_authorization(payload: AuthorizationRequest) -> AuthorizationResponse:
    return execute_authorization(payload)
