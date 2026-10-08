import os

from app.api.routes.health import router as health_router
from app.api.routes.kyc import router as kyc_router
from app.api.routes.admin import router as admin_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

origins = [origin.strip() for origin in os.getenv('CORS_ORIGINS', 'http://localhost,http://127.0.0.1,http://10.0.2.2').split(',') if origin.strip()]
app = FastAPI(title="GEMCARDS API", version="0.1.0", description="Demo KYC orchestration; not production KYC.")
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_credentials=False, allow_methods=["*"], allow_headers=["*"])
app.include_router(health_router)
app.include_router(kyc_router)
app.include_router(admin_router)
