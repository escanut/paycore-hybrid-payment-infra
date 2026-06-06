from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from database import Base

class Ledger(Base):
    __tablename__ = "ledger"

    id = Column(String, primary_key=True)
    account_id = Column(String, ForeignKey("accounts.id"))


    account = relationship("Account", back_populates="ledger")
    