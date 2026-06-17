from sqlalchemy import Column, String, DateTime
from sqlalchemy.orm import relationship
from database import Base
import datetime

class User(Base):
    __tablename__ = "users"

    username = Column(String, primary_key=True)
    merchant_id = Column(String, nullable=False, unique=True)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    accounts = relationship("Account", back_populates="users")
    idempotency_keys = relationship("IdempotencyKey", back_populates="users")