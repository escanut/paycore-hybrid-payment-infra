from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from db_models.db_transaction import Transaction, Transaction_Status
from response_schemas.payment import PaymentRequest, PaymentResponse
from services.tokeniser import tokenise_pan
import logging

router = APIRouter(prefix="/payment", tags=["Payments"])

logger = logging.getLogger(__name__)

@router.post("/", response_model=PaymentResponse)
def process_payment(req: PaymentRequest, db: Session = Depends(get_db)):
    
    logger.info("Payment request received", extra={
        "merchant_id": req.merchant_id,
        "amount": req.amount,
        "currency": req.currency
    })

    try:

        token, masked = tokenise_pan(req.pan)
        logger.info("PAN tokenised", extra={"masked_pan": masked, "token": token})

        
        tx = Transaction(
            token = token,
            merchant_id = req.merchant_id,
            amount = req.amount,
            currency = req.currency,
            status = Transaction_Status.queued
        )

        # We wil add the ability to forward this to sqs later

        db.add(tx)
        db.commit()
        db.refresh(tx)

        logger.info("Transaction persisted", extra={
            "merchant_id": tx.merchant_id,
            "status": tx.status
        })
    
    except Exception as e:
        db.rollback()
        logger.exception("Transaction Failed", extra={
            "merchant_id":req.merchant_id
        })

        raise HTTPException(status_code=500, detail=f"Transaction Failed")


    return PaymentResponse(
        status = tx.status,
        token = token,
        amount = req.amount,
        currency = req.currency
    )

