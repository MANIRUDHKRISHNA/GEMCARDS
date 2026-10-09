from fastapi import APIRouter, HTTPException, Query

from app.domain import store
from app.schemas.domain import (
    Card,
    CardApplication,
    CardApplicationCreate,
    CardControls,
    CardStatus,
    CardStatusUpdate,
    VirtualCardCreate,
)

router = APIRouter(prefix="/api/v1/cards", tags=["cards"])


@router.get("", response_model=list[Card])
def list_cards(
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> list[Card]:
    selected_customer_id = customer_id or store.DEMO_CUSTOMER_ID
    store.get_customer(selected_customer_id)
    return [
        card for card in store.cards.values()
        if card.customer_id == selected_customer_id
    ]


@router.post(
    "/applications",
    response_model=CardApplication,
    status_code=201,
)
def create_card_application(payload: CardApplicationCreate) -> CardApplication:
    return store.create_card_application(payload.customer_id, payload.product)


@router.get("/applications", response_model=list[CardApplication])
def list_card_applications() -> list[CardApplication]:
    return list(store.card_applications.values())


@router.get(
    "/applications/{application_id}",
    response_model=CardApplication,
)
def card_application_detail(application_id: str) -> CardApplication:
    application = store.card_applications.get(application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Card application not found")
    return application


@router.get("/{card_id}", response_model=Card)
def card_detail(card_id: str) -> Card:
    return store.get_card(card_id)


@router.post("/{card_id}/freeze", response_model=Card)
def freeze_card(card_id: str) -> Card:
    return _transition_card(card_id, "frozen")


@router.post("/{card_id}/unfreeze", response_model=Card)
def unfreeze_card(card_id: str) -> Card:
    return _transition_card(card_id, "active")


@router.post("/{card_id}/transition", response_model=Card)
def transition_card(card_id: str, payload: CardStatusUpdate) -> Card:
    return _transition_card(card_id, payload.status)


@router.patch("/{card_id}/controls", response_model=Card)
def update_card_controls(card_id: str, payload: CardControls) -> Card:
    card = store.get_card(card_id)
    changes = payload.model_dump(exclude_unset=True)
    for name, value in changes.items():
        setattr(card, name, value)
    store.save_entity("cards", card)
    store.record_audit_event(
        "CARD_CONTROLS_UPDATED",
        customer_id=card.customer_id,
        card_id=card.id,
        details=changes,
    )
    return card


@router.post("/virtual", response_model=Card, status_code=201)
def create_virtual_card(
    payload: VirtualCardCreate,
    customer_id: str | None = Query(default=None, min_length=1, max_length=40),
) -> Card:
    next_number = 2
    while f"CARD-V{next_number:02d}" in store.cards:
        next_number += 1
    suffix = f"{9104 + next_number - 1:04d}"
    card = Card(
        id=f"CARD-V{next_number:02d}",
        customer_id=customer_id or store.DEMO_CUSTOMER_ID,
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
    store.get_customer(card.customer_id)
    store.cards[card.id] = card
    store.save_entity("cards", card)
    store.record_audit_event(
        "CARD_ISSUED",
        customer_id=card.customer_id,
        card_id=card.id,
        details={"card_type": card.card_type, "product": card.product},
    )
    return card


def _transition_card(card_id: str, status: CardStatus) -> Card:
    try:
        return store.transition_card(card_id, status)
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
