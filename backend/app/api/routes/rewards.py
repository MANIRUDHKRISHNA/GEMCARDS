from fastapi import APIRouter, Query

from app.domain import store
from app.schemas.domain import RewardSummary

router = APIRouter(prefix="/api/v1/rewards", tags=["rewards"])


@router.get("", response_model=RewardSummary)
def customer_rewards(
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> RewardSummary:
    return store.get_rewards(customer_id or store.DEMO_CUSTOMER_ID)
