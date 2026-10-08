from datetime import datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from app.domain import store

router = APIRouter(prefix="/api/v1/kyc", tags=["kyc"])


class SessionCreate(BaseModel):
    country: str = Field(min_length=2, max_length=80)
    document_type: Literal["Passport", "Driver's License", "National ID"]
    customer_id: str = Field(
        default=store.DEMO_CUSTOMER_ID,
        min_length=1,
        max_length=40,
    )


class DocumentData(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    dob: str = Field(min_length=4, max_length=32)
    id_number: str = Field(min_length=4, max_length=64)
    front_captured: bool = True
    back_captured: bool = True


class SelfieData(BaseModel):
    liveness_passed: bool = True
    face_match_score: float = Field(default=0.96, ge=0, le=1)


class AddressData(BaseModel):
    address: str = Field(min_length=5, max_length=500)
    document_name: str = Field(min_length=1, max_length=255)


class SubmitData(BaseModel):
    pep_declared: bool
    terms_accepted: bool


class Session(BaseModel):
    id: str
    customer_id: str
    country: str
    document_type: str
    status: Literal["draft", "verified"] = "draft"
    document: dict[str, Any] = Field(default_factory=dict)
    selfie: dict[str, Any] = Field(default_factory=dict)
    address: dict[str, Any] = Field(default_factory=dict)
    declarations: dict[str, bool] = Field(default_factory=dict)
    created_at: str
    updated_at: str


sessions: dict[str, Session] = {}
_session_sequence = 0


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get(session_id: str) -> Session:
    session = sessions.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="KYC session not found")
    return session


def save(session: Session) -> Session:
    session.updated_at = now()
    sessions[session.id] = session
    return session


@router.post("/session", response_model=Session)
def create(payload: SessionCreate) -> Session:
    global _session_sequence
    _session_sequence += 1
    stamp = now()
    customer = store.get_customer(payload.customer_id)
    session = Session(
        id=f"KYC-DEMO-{_session_sequence:04d}",
        customer_id=customer.id,
        country=payload.country,
        document_type=payload.document_type,
        created_at=stamp,
        updated_at=stamp,
    )
    sessions[session.id] = session
    if customer.application_status != "card_active" and customer.kyc_status != "verified":
        customer.application_status = "kyc_in_progress"
        customer.kyc_status = "in_progress"
    return session


@router.get("/{session_id}", response_model=Session)
def read(session_id: str) -> Session:
    return get(session_id)


@router.get("/{session_id}/status", response_model=Session)
def status(session_id: str) -> Session:
    return get(session_id)


@router.post("/{session_id}/document", response_model=Session)
def document(session_id: str, payload: DocumentData) -> Session:
    session = get(session_id)
    session.document = payload.model_dump()
    return save(session)


@router.post("/{session_id}/selfie", response_model=Session)
def selfie(session_id: str, payload: SelfieData) -> Session:
    session = get(session_id)
    session.selfie = payload.model_dump()
    return save(session)


@router.post("/{session_id}/address", response_model=Session)
def address(session_id: str, payload: AddressData) -> Session:
    session = get(session_id)
    session.address = payload.model_dump()
    return save(session)


@router.post("/{session_id}/address/upload")
async def upload(session_id: str, file: UploadFile = File(...)) -> dict[str, Any]:
    get(session_id)
    allowed_types = {"application/pdf", "image/jpeg", "image/png"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=415,
            detail="Only PDF, JPG, JPEG, and PNG files are accepted",
        )
    content = await file.read(10 * 1024 * 1024 + 1)
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Prototype limit is 10 MB")
    return {
        "filename": file.filename,
        "content_type": file.content_type,
        "size": len(content),
        "accepted": True,
    }


@router.post("/{session_id}/submit", response_model=Session)
def submit(session_id: str, payload: SubmitData) -> Session:
    if not payload.terms_accepted:
        raise HTTPException(status_code=400, detail="Terms must be accepted")
    session = get(session_id)
    if session.status == "verified":
        return session
    if not session.document or not session.selfie or not session.address:
        raise HTTPException(
            status_code=409,
            detail="Document, liveness, and address steps are required",
        )
    if not session.selfie.get("liveness_passed", False):
        raise HTTPException(
            status_code=409,
            detail="Liveness verification did not pass",
        )
    session.declarations = payload.model_dump()
    session.status = "verified"
    store.complete_customer_kyc(session.customer_id)
    return save(session)
