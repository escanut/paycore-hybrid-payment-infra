from fastapi import Header, HTTPException
from config import CALLBACK_API_KEY
import logging


logger = logging.getLogger(__name__)

# Takes the queried Header section of a request
def verify_callback_token(x_api_key: str = Header(...)):
    logger.info("Checking request header", extra={
        "header" : x_api_key
    })
    
    
    if x_api_key != CALLBACK_API_KEY:
        logger.info("Callback api key fail", extra={
                "header" : x_api_key
        })

        raise HTTPException(status_code=403, detail="Forbidden")

