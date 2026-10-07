from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="GEMCARDS",
    version="0.1.0",
    description=" KYC orchestration API for the Flutter prototype.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class KycStatus(str, Enum):
    draft = "draft"
    processing = "processing"
    verified = "verified"
    under_review = "under_review"
    action_required = "action_required"


class Session(BaseModel):
    id: str
    country: str = "India"
    document_type: str = "National ID Card"
    status: KycStatus = KycStatus.draft
    document: dict[str, Any] = Field(default_factory=dict)
    selfie: dict[str, Any] = Field(default_factory=dict)
    address: dict[str, Any] = Field(default_factory=dict)
    declarations: dict[str, bool] = Field(default_factory=dict)
    created_at: str
    updated_at: str


class SessionCreate(BaseModel):
    country: str = "India"
    document_type: str = "National ID Card"


class DocumentData(BaseModel):
    name: str = "Demo Applicant"
    dob: str = "14 Aug 2005"
    id_number: str = "XXXX-XXXX-1234"
    front_captured: bool = True
    back_captured: bool = True


class SelfieData(BaseModel):
    liveness_passed: bool = True
    face_match_score: float = Field(default=0.96, ge=0, le=1)


class AddressData(BaseModel):
    address: str
    document_name: str


class SubmitData(BaseModel):
    pep_declared: bool
    terms_accepted: bool


sessions: dict[str, Session] = {}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_session(session_id: str) -> Session:
    session = sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="KYC session not found")
    return session


def touch(session: Session) -> Session:
    session.updated_at = now()
    sessions[session.id] = session
    return session


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "jiffy-kyc-prototype"}


@app.post("/api/v1/kyc/session", response_model=Session)
def create_session(payload: SessionCreate) -> Session:
    timestamp = now()
    session = Session(
        id=str(uuid4()),
        country=payload.country,
        document_type=payload.document_type,
        created_at=timestamp,
        updated_at=timestamp,
    )
    sessions[session.id] = session
    return session


@app.get("/api/v1/kyc/{session_id}", response_model=Session)
def read_session(session_id: str) -> Session:
    return get_session(session_id)


@app.post("/api/v1/kyc/{session_id}/document", response_model=Session)
def save_document(session_id: str, payload: DocumentData) -> Session:
    session = get_session(session_id)
    session.document = payload.model_dump()
    return touch(session)


@app.post("/api/v1/kyc/{session_id}/selfie", response_model=Session)
def save_selfie(session_id: str, payload: SelfieData) -> Session:
    session = get_session(session_id)
    session.selfie = payload.model_dump()
    return touch(session)


@app.post("/api/v1/kyc/{session_id}/address", response_model=Session)
def save_address(session_id: str, payload: AddressData) -> Session:
    session = get_session(session_id)
    session.address = payload.model_dump()
    return touch(session)


@app.post("/api/v1/kyc/{session_id}/address/upload")
async def upload_address_document(session_id: str, file: UploadFile = File(...)) -> dict[str, Any]:
    get_session(session_id)
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Prototype limit is 10 MB")
    return {
        "filename": file.filename,
        "content_type": file.content_type,
        "size": len(contents),
        "accepted": True,
    }


@app.post("/api/v1/kyc/{session_id}/submit", response_model=Session)
def submit(session_id: str, payload: SubmitData) -> Session:
    session = get_session(session_id)
    if not payload.terms_accepted:
        raise HTTPException(status_code=400, detail="Terms must be accepted")
    session.declarations = payload.model_dump()
    session.status = KycStatus.processing
    touch(session)

    # Deliberately deterministic demo outcome. Replace this block with an approved
    # KYC provider/orchestrator in a real implementation.
    session.status = KycStatus.verified
    return touch(session)
