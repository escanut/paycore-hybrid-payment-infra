from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from database import get_db
from db_models.db_ledger import LedgerMovement
from db_models.db_transaction import Transaction, Transaction_Status
from db_models.db_user import User
from response_schemas.payment import PaymentRequest, PaymentResponse
from services.tokeniser import tokenise_pan
from services.auth_service import get_current_user
from services.ledger_service import get_account, check_idempotency, ledger_entry, store_idempotency
import logging
import boto3
from config import AWS_REGION, SQS_QUEUE_URL
import json

router = APIRouter(prefix="/payments", tags=["Payments"])

logger = logging.getLogger(__name__)

sqs = boto3.client('sqs', region_name=AWS_REGION)

@router.post("/", response_model=PaymentResponse)
def process_payment(req: PaymentRequest, 
                    db: Session = Depends(get_db), 
                    current_user: User = Depends(get_current_user),
                    idempotency_key: str = Header(None, alias="Idempotency-Key")
):
    
    logger.info("Payment request received", extra={
        "merchant_id": current_user.merchant_id,
        "amount": req.amount,
        "currency": req.currency
    })

    try:

        if idempotency_key:
            cached = check_idempotency(db, idempotency_key, current_user.merchant_id)
            if cached:
                logger.info("Idempotent replay: duplicate transaction", extra={"idempotency_key": idempotency_key})
                return PaymentResponse(**json.loads(cached))
        
        account = get_account(db, current_user.merchant_id, req.currency)

        # Generate token and masked PAN using our tokenisation service.
        token, masked_pan = tokenise_pan(req.pan)
        logger.info("PAN tokenised", extra={"masked_pan": masked_pan, "token": token})

        
        tx = Transaction(
            token = token,
            merchant_id = current_user.merchant_id,
            amount = req.amount,
            currency = req.currency,
            masked_pan = masked_pan,
            status = Transaction_Status.queued
        )

        db.add(tx)
        db.flush()

        # Update Ledger
        ledger_entry(db, account.id, LedgerMovement.credit, req.amount, token)
        

        logger.info("Transaction persisted", extra={
            "merchant_id": tx.merchant_id,
            "status": tx.status
        })

        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "token": tx.token,
                "merchant_id": tx.merchant_id,
                "amount": str(tx.amount),
                "currency": tx.currency,
                "status": tx.status.value
            }),
        )

        if idempotency_key:
            store_idempotency(db, idempotency_key, current_user.merchant_id, response.model_dump_json())

        db.commit()


    
    except Exception as e:
        db.rollback()
        logger.exception("Transaction Failed", extra={
            "merchant_id": current_user.merchant_id
        })

        raise HTTPException(status_code=500, detail=f"Transaction Failed")


    return PaymentResponse(
        status = tx.status,
        token = token,
        masked_pan = masked_pan,
        amount = req.amount,
        currency = req.currency
    )

