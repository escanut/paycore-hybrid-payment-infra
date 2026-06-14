from sqlalchemy import Column, String, DateTIme, Float
from sqlalchemy.orm import relationship
from database import Base
import enum, datetime


# To Know the type of ledger movement
class LedgerMovement(str, enum.Enum):
    credit = "credit"
    debit = "debit"

class LedgerEntry(Base):
    __tablename__ = "ledger_entry"

    id = Column(String, primary_key=True)
    account_id = Column(String, ForeignKey("accounts.id"), nullable=False, index=True)
    movement_direction = Column(Enum(LedgerMovement), nullable=False)
    amount = Column(Float, nullable=False)
    transaction_token = Column(String, ForeignKey("transaction.token"), nullable=False, unique=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    account = relationship("Account", back_populates="ledger_entry")
    transaction = relationship("Transaction", back_populates="ledger_entry")