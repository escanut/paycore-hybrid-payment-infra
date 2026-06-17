from pydantic import BaseModel
from datetime import datetime



class AccountCreationResponse(BaseModel):
    id : str
    merchant_id : str
    currency : str
    created_at : datetime

class AccountInformationResponse(BaseModel):
    id : str
    currency: str
    created_at : datetime

    class Config:
        from_attributes = True
    

