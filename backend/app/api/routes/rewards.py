from fastapi import APIRouter

from app.domain import store
from app.schemas.domain import RewardSummary

router = APIRouter(prefix="/api/v1/rewards", tags=["rewards"])


@router.get("", response_model=RewardSummary)
def customer_rewards() -> RewardSummary:
    return store.get_rewards(store.DEMO_CUSTOMER_ID)
