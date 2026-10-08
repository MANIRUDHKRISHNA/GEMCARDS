from typing import Any, Literal
from uuid import uuid4
from datetime import datetime, timezone
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

router = APIRouter(prefix='/api/v1/kyc', tags=['kyc'])

class SessionCreate(BaseModel):
    country: str = Field(min_length=2, max_length=80)
    document_type: Literal['Passport', "Driver's License", 'National ID']
class DocumentData(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    dob: str = Field(min_length=4, max_length=32)
    id_number: str = Field(min_length=4, max_length=64)
    front_captured: bool = True
    back_captured: bool = True
class SelfieData(BaseModel): liveness_passed: bool = True; face_match_score: float = Field(0.96, ge=0, le=1)
class AddressData(BaseModel):
    address: str = Field(min_length=5, max_length=500)
    document_name: str = Field(min_length=1, max_length=255)
class SubmitData(BaseModel): pep_declared: bool; terms_accepted: bool
class Session(BaseModel):
    id: str; country: str; document_type: str; status: str = 'draft'; document: dict[str, Any] = Field(default_factory=dict); selfie: dict[str, Any] = Field(default_factory=dict); address: dict[str, Any] = Field(default_factory=dict); declarations: dict[str, bool] = Field(default_factory=dict); created_at: str; updated_at: str

sessions: dict[str, Session] = {}
def now() -> str: return datetime.now(timezone.utc).isoformat()
def get(session_id: str) -> Session:
    if session_id not in sessions: raise HTTPException(404, 'KYC session not found')
    return sessions[session_id]
def save(session: Session) -> Session: session.updated_at = now(); sessions[session.id] = session; return session

@router.post('/session', response_model=Session)
def create(payload: SessionCreate) -> Session:
    stamp = now(); session = Session(id=str(uuid4()), country=payload.country, document_type=payload.document_type, created_at=stamp, updated_at=stamp); sessions[session.id] = session; return session
@router.get('/{session_id}', response_model=Session)
def read(session_id: str) -> Session: return get(session_id)
@router.get('/{session_id}/status', response_model=Session)
def status(session_id: str) -> Session: return get(session_id)
@router.post('/{session_id}/document', response_model=Session)
def document(session_id: str, payload: DocumentData) -> Session: session = get(session_id); session.document = payload.model_dump(); return save(session)
@router.post('/{session_id}/selfie', response_model=Session)
def selfie(session_id: str, payload: SelfieData) -> Session: session = get(session_id); session.selfie = payload.model_dump(); return save(session)
@router.post('/{session_id}/address', response_model=Session)
def address(session_id: str, payload: AddressData) -> Session: session = get(session_id); session.address = payload.model_dump(); return save(session)
@router.post('/{session_id}/address/upload')
async def upload(session_id: str, file: UploadFile = File(...)) -> dict[str, Any]:
    get(session_id)
    allowed = {'application/pdf', 'image/jpeg', 'image/png'}
    if file.content_type not in allowed:
        raise HTTPException(415, 'Only PDF, JPG, JPEG, and PNG files are accepted')
    content = await file.read(10 * 1024 * 1024 + 1)
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(413, 'Prototype limit is 10 MB')
    return {'filename': file.filename, 'content_type': file.content_type, 'size': len(content), 'accepted': True}
@router.post('/{session_id}/submit', response_model=Session)
def submit(session_id: str, payload: SubmitData) -> Session:
    if not payload.terms_accepted: raise HTTPException(400, 'Terms must be accepted')
    session = get(session_id); session.declarations = payload.model_dump(); session.status = 'verified'; return save(session)
