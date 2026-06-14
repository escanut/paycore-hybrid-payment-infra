from sqlalchemy import Column, String, DateTime, Enum
from sqlalchemy.orm import relationship
import enum, datetime
from database import Base


class Account_Currency(str, enum.Enum):
    NGN = "NGN"
    USD = "USD"
    EUR = "EUR"


class Account(Base):
    __tablename__ = "accounts"

    id = Column(String, primary_key=True)
    merchant_id = Column(String, ForeignKey("users.merchant_id"), nullable=False)
    currency = Column(Enum(Account_Currency), default=Account_Currency.NGN)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="accounts")
    ledgers = relationship("Ledger_Entry", back_populates="accounts")