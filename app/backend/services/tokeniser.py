import uuid, hashlib

# For masking the pan we store in postgresql
def tokenise_pan(pan: str) -> tuple[str, str]:
    
    token = str(uuid.uuid4())
    masked = "**** **** ****" + pan[-4:]
    return token, masked
    