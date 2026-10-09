import os

from app.api.routes.health import router as health_router
from app.api.routes.kyc import router as kyc_router
from app.api.routes.admin import router as admin_router
from app.api.routes.customer import router as customer_router
from app.api.routes.cards import router as cards_router
from app.api.routes.transactions import router as transactions_router
from app.api.routes.fraud import router as fraud_router
from app.api.routes.disputes import router as disputes_router
from app.api.routes.rewards import router as rewards_router
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from app.domain.database import DatabaseError

origins = [origin.strip() for origin in os.getenv('CORS_ORIGINS', 'http://localhost,http://127.0.0.1,http://10.0.2.2').split(',') if origin.strip()]
app = FastAPI(title="GEMCARDS API", version="0.2.0", description="Deterministic SQLite-backed GEMCARDS demo API. Not for real payments or identity verification.")
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=False, allow_methods=["*"], allow_headers=["*"])


@app.exception_handler(DatabaseError)
async def database_error_handler(
    _request: Request,
    _error: DatabaseError,
) -> JSONResponse:
    _ = (_request, _error)
    return JSONResponse(
        status_code=503,
        content={"detail": "Persistent demo storage is temporarily unavailable"},
    )


app.include_router(health_router)
app.include_router(kyc_router)
app.include_router(admin_router)
app.include_router(customer_router)
app.include_router(cards_router)
app.include_router(transactions_router)
app.include_router(fraud_router)
app.include_router(disputes_router)
app.include_router(rewards_router)
