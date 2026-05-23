from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class PaymentRequest(BaseModel):
    pan: str # primary account number
    amount: float
    currency: str = "NGN"

    # We verify pan before usage
    @field_validator("pan")
    @classmethod
    def pan_digits_only(cls, v):

        cleaned = v.replace(" ", "")
        if not cleaned.isdigit(): # if we remove spaces and is n
            logger.warning("PAN must be numeric")
            raise ValueError("PAN must be numeric")

        if len(cleaned) < 4:
            logger.warning("PAN is too short")
            raise ValueError("PAN is too short")

        logger.info(f"Validated PAN: {cleaned}" )
        return cleaned

class PaymentResponse(BaseModel):
    status: str
    token: str
    masked_pan: str
    amount: float
    currency: str


class TransactionResponse(BaseModel):
    token: str
    merchant_id: str
    amount: float
    currency: str
    masked_pan: str
    status: str
    created_at: datetime

    # For allowing Pydantic to read ORM objects 
    class Config:
        from_attributes = True

