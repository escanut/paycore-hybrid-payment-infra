from sqlalchemy import Column, String, DateTime, Enum
from sqlalchemy.orm import relationship
import enum, datetime
from database import Base

# Enum class to show if account is active
class Account_Status(str, enum.Enum):
    active = "active"
    disabled = "disabled"



class Account(Base):
    __tablename__ = "accounts"

    id = Column(String, primary_key=True)
    merchant_id = (String, ForeignKey("users.merchant_id"))

    user = relationship("User", back_populates="accounts")
    ledgers = relationship("Ledger", back_populates="accounts")