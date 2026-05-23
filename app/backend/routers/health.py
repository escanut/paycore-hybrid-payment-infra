from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
import logging

router = APIRouter(tags=["Health"])
logger = logging.getLogger(__name__)

@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        db_status = "ok"
        

    except Exception as e:
        db_status = "unreachable"
        logger.info("Health Check failed", extra={
            "error": str(e)
        })
        print(f"It works")
    
    return {
        "api": "ok",
        "database": db_status
    }

