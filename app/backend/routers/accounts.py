from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from response_schemas.account_schema import AccountCreationResponse, AccountInformationResponse
from db_models.db_account import Account, Account_Currency
from db_models.db_user import User
from services.auth_service import get_current_user
from services.ledger_service import get_account, get_balance

import uuid, logging
from typing import List

router = APIRouter(prefix="/accounts", tags=["Accounts"])
logger = logging.getLogger(__name__)

@router.post("/", response_model=AccountCreationResponse)
def create_account(
    currency: Account_Currency, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    existing = db.query(Account).filter(
        Account.merchant_id == current_user.merchant_id,
        Account.currency == currency
    ).first()

    if existing:
        raise HTTPException(status_code=409, detail=f"{currency} account already exists: {existing.account_id}" )
    
    try:
        account = Account(
            id = str(uuid.uuid4()),
            merchant_id = current_user.merchant_id,
            currency = currency

        )       

        db.add(account)
        db.commit()
        db.refresh(account)

        logger.info("Account created", extra = {
            "merchant_id": current_user.merchant_id,
            "currency" : currency
        })

        return account

    except Exception as e:
        db.rollback()
        logger.error("Account creation failed", extra={"error": str(e)})
        raise HTTPException(status_code=500, detail="Account creation failed")
    


@router.get("/", response_model=List[AccountInformationResponse])
def list_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    accounts = db.query(Account).filter(
        Account.merchant_id == current_user.merchant_id
    ).all()

    logger.info("Retrieved all accounts", extra={
        "merchant_id" : current_user.merchant_id 
    })

    return accounts

@router.get("/{account_id}", response_model=AccountInformationResponse)
def get_account_by_id(
    account_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    account = db.query(Account).filter(
        Account.id == account_id,
        Account.merchant_id == current_user.merchant_id
    ).first()

    if not account:
        logger.info("Account not found", extra={
            "account_id": account_id,
            "merchant_id": current_user.merchant_id
        })

        raise HTTPException(status_code=404, detail="Account not found")

    logger.info("Retrieved Account info", extra={
        "äccount_id": account_id,
        "merchant_id" : current_user.merchant_id
    })

    return account
    

# For getting the balance
@router.get("/balance/{currency}")
def get_merchant_balance(currency: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    account = get_account(db, current_user.merchant_id, currency)
    balance = get_balance(db, account.id)
    return {
        "account_id": account.id,
        "currency": account.currency,
        "balance": balance
    }