from fastapi import FastAPI
from routers import payments, health, transactions
from fastapi.middleware.cors import CORSMiddleware
import logger

app = FastAPI(
    
    title="Paycore API",
    description="B2B Payment Processing Middleware",
    version="0.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://victorojeje.xyz"],
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["Content-Type"]
)

app.include_router(payments.router, prefix="/api")
app.include_router(health.router, prefix="/api")
app.include_router(transactions.router, prefix="/api")
