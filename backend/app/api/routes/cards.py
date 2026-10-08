from fastapi import APIRouter, HTTPException

from app.domain import store
from app.schemas.domain import Card, CardControls, VirtualCardCreate

router = APIRouter(prefix="/api/v1/cards", tags=["cards"])


@router.get("", response_model=list[Card])
def list_cards() -> list[Card]:
    return list(store.cards.values())


@router.get("/{card_id}", response_model=Card)
def card_detail(card_id: str) -> Card:
    return store.get_card(card_id)


@router.post("/{card_id}/freeze", response_model=Card)
def freeze_card(card_id: str) -> Card:
    card = store.get_card(card_id)
    if card.status == "closed":
        raise HTTPException(status_code=409, detail="Closed cards cannot be frozen")
    card.status = "frozen"
    return card


@router.post("/{card_id}/unfreeze", response_model=Card)
def unfreeze_card(card_id: str) -> Card:
    card = store.get_card(card_id)
    if card.status == "closed":
        raise HTTPException(status_code=409, detail="Closed cards cannot be unfrozen")
    card.status = "active"
    return card


@router.patch("/{card_id}/controls", response_model=Card)
def update_card_controls(card_id: str, payload: CardControls) -> Card:
    card = store.get_card(card_id)
    for name, value in payload.model_dump(exclude_unset=True).items():
        setattr(card, name, value)
    return card


@router.post("/virtual", response_model=Card, status_code=201)
def create_virtual_card(payload: VirtualCardCreate) -> Card:
    next_number = 2
    while f"CARD-V{next_number:02d}" in store.cards:
        next_number += 1
    suffix = f"{9104 + next_number - 1:04d}"
    card = Card(
        id=f"CARD-V{next_number:02d}",
        customer_id=store.DEMO_CUSTOMER_ID,
        product=payload.nickname,
        card_type="virtual",
        network="Visa",
        masked_number=f"•••• {suffix}",
        expiry="09/30",
        status="active",
        daily_limit=payload.daily_limit,
        international_enabled=False,
        contactless_enabled=False,
        online_enabled=True,
        atm_enabled=False,
    )
    store.cards[card.id] = card
    return card
