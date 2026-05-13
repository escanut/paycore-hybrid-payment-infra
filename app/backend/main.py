from fastapi import FastAPI
from routers import payments, health, transactions
from database import init_db
import logger

app = FastAPI(
    
    title="Paycore API",
    description="B2B Payment Processing Middleware",
    version="0.1.0"
)

app.include_router(payments.router, prefix="/api")
app.include_router(health.router, prefix="/api")
app.include_router(transactions.router, prefix="/api")

init_db()