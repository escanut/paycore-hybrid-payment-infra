import uuid, json
from sqlalchemy import select
from sqlalchemy.orm import Session
from fastapi import HTTPException
from db_models.db_account import Account, Account_Currency
from db_models.db_ledger import LedgerEntry, LedgerMovement
from db_models.db_idempotency import IdempotencyKey

def get_account(db: Session, merchant_id: str, currency: str):
    account = db.query(Account).filter(
        Account.merchant_id == merchant_id,
        Account.currency == currency
    ).first()

    if not account:
        raise HTTPException(
            status_code=422,
            detail=f"No {currency} account found for this merchant. "
                   f"Create one via POST /api/accounts before accepting {currency} payments."
        )
    
    return account
   



# Credit/Debit our Ledger
def ledger_entry(db: Session, account_id: str, movement_direction: LedgerMovement, amount: float, transaction_token: str ):
    entry = LedgerEntry(
        id = str(uuid.uuid4()),
        account_id = account_id,
        movement_direction = movement_direction,
        amount = amount,
        transaction_token = transaction_token
    )

    db.add(entry)
    return entry


def get_balance(db: Session, account_id: str):
    rows = db.execute(
        select(LedgerEntry).where(LedgerEntry.account_id == account_id)
    ).scalars().all()
    
    balance = 0.0
    for row in rows:
        if row.movement_direction == LedgerMovement.credit:
            balance += row.amount
        else:
            balance -= row.amount

    return balance


def check_idempotency(db: Session, key: str, merchant_id: str):
    record = db.query(IdempotencyKey).filter(
        IdempotencyKey.key == key,
        IdempotencyKey.merchant_id == merchant_id
    ).first()

    if record:
        return record.response_body
    
    else:
        return None

def store_idempotency(db: Session, key: str, merchant_id: str, response_body: str):
    record = IdempotencyKey(
        key = key,
        merchant_id = merchant_id,
        response_body = response_body
    )

    db.add(record)