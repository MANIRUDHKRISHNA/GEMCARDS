from fastapi import APIRouter

from app.domain import store
from app.domain.authorization import execute_authorization
from app.schemas.domain import (
    AuthorizationRequest,
    AuthorizationResponse,
    Transaction,
)

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])


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
    return execute_authorization(payload)
