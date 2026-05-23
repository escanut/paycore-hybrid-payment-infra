from sqlalchemy import Column, String, Float, DateTime, Enum
import enum, datetime
from database import Base # To avoid circular import dependency

# Enum class to handle transaction status
class Transaction_Status(str, enum.Enum):
    queued = "queued"
    processed = "processed"
    failed = "failed"
    flagged = "flagged"

# Transaction table for our database
class Transaction(Base):
    __tablename__ = "transaction"

    token = Column(String, primary_key=True)
    merchant_id = Column(String, nullable=False, index=True)
    amount = Column(Float, nullable=False)
    masked_pan = Column(String, nullable=False)
    currency = Column(String(3), default="NGN")
    status = Column(Enum(Transaction_Status), default=Transaction_Status.queued)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)