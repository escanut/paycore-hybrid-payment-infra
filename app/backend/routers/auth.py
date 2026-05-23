from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from db_models.db_user import User
from services.auth_service import get_current_user, hash_password, verify_password, create_access_token
from response_schemas.auth_schema import RegisterRequest, LoginRequest
from database import get_db
import uuid
import logging

router = APIRouter(prefix="/auth", tags=["Auth"])
logger = logging.getLogger(__name__)

@router.post("/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):

    try:    

        existing = db.query(User).filter(User.username == req.username).first()
        if existing:
            raise HTTPException(status_code=400, detail="Username already exists")
        
        # We generate a unique merchant ID for each user, which can be used for tracking and other purposes. The ID is created by taking a UUID, converting it to a string, slicing the first 8 characters, and prefixing it with "Merchant-". This ensures that each merchant ID is unique and easily identifiable.
        merchant_id = f"Merchant-{str(uuid.uuid4())[:8].upper()}"
        
        print("RAW PASSWORD:", req.password)
        print("LEN:", len(req.password.encode("utf-8")))

        user = User(
            username = req.username,
            merchant_id = merchant_id,
            hashed_password = hash_password(req.password)

        )

        db.add(user)
        db.commit()
        db.refresh(user)

        logger.info("User registered", extra={
            "username": user.username, 
            "merchant_id": user.merchant_id}
        
        )

    except Exception as e:
        db.rollback()
        logger.error("Error occurred while registering user", extra={"error": str(e)})
        raise HTTPException(status_code=500, detail="Internal server error")

    return {"message": "User registered successfully", "merchant_id": user.merchant_id}


@router.post("/login")
def login(req: LoginRequest, db: Session = Depends(get_db)):

    try:
        user = db.query(User).filter(User.username == req.username).first()
        if not user or not verify_password(req.password, user.hashed_password):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        token = create_access_token(data={"sub": user.username})

        logger.info("User logged in", extra={"username": user.username})

    except Exception as e:
        logger.error("Error occurred during login", extra={"error": str(e)})
        raise HTTPException(status_code=500, detail="Internal server error")

    return {"access_token": token, "token_type": "bearer"}


@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "username": current_user.username, 
        "merchant_id": current_user.merchant_id
        
        }