from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from db_models.db_transaction import Transaction
from response_schemas.payment import TransactionResponse
from typing import List
from db_models.db_user import User
from services.auth_service import get_current_user
from services.dependencies import verify_callback_token
import logging

router = APIRouter(prefix="/transactions", tags=["Transactions"])
logger = logging.getLogger(__name__)

# We add query to limit the db calls
@router.get("/", response_model=List[TransactionResponse])
def list_transactions(
    skip: int = 0, limit: int = Query(default=50, le=100), 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        transactions = db.query(Transaction).filter(Transaction.merchant_id == current_user.merchant_id).offset(skip).limit(limit).all()

        logger.info("Transactions retrieved", extra={
            "count": len(transactions)
        })

        return transactions

    except Exception as e:
        logger.exception("Failed to fetch transactions", extra={
            "error": str(e)
        })

        raise HTTPException(status_code=500, detail="Failed to retrieve transactions")


# We want a specific transaction
@router.get("/{token}", response_model=TransactionResponse)
def get_transaction(token: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    
    try:
        tx = db.query(Transaction).filter(Transaction.token == token, Transaction.merchant_id == current_user.merchant_id).first()

        logger.info("Transaction retrieved", extra={
            "merchant_id": tx.merchant_id,
            "created_at" : tx.created_at
        })

        return tx

    except Exception as e:
        logger.exception("Failed to fetch transaction", extra={
            "error" : str(e)
        })

        raise HTTPException(status_code=500, detail="Failed to fetch transaction")



# we use it only to patch status
# Lambda will use this to after it has validated the transaction
@router.patch("/{token}/status")
def update_status(token: str, status: str, db: Session = Depends(get_db), _: None = Depends(verify_callback_token)):
    
    try:
        tx = db.query(Transaction).filter(Transaction.token == token).first()

        logger.info("Transaction retrieved", extra={
            "merchant_id": tx.merchant_id,
            "created_at" : tx.created_at 
        })

        tx.status = status

        db.commit()

        logger.info("Transaction retrieved", extra={
            "merchant_id": tx.merchant_id,
            "created_at" : tx.created_at 
        })

        return {
            "token": token, 
            "status": status
        }


    except Exception as e:
        db.rollback()
        logger.exception("Failed to patch transaction status", extra={
            "error" : str(e)
        })
        raise HTTPException(status_code=500, detail="Failed to update status")
    
