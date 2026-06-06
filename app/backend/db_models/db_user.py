from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    username = Column(String, primary_key=True)
    merchant_id = Column(String, nullable=False, unique=True)
    hashed_password = Column(String, nullable=False)

    accounts = relationship("Account", back_populates="users")