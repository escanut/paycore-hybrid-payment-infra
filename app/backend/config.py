# Simply to handle loading our environment variables
from pydantic_settings import BaseSettings, SettingsConfigDict

import boto3
import json
import os


# We keep pydantic for loading the env file
class Settings(BaseSettings):
    aws_region: str

    model_config = SettingsConfigDict(
        env_file= ".env",
        env_file_encoding= "utf-8",
        extra= "ignore"
    )


settings = Settings()

# We are using kms + secrets manager
def load_secrets():
    client = boto3.client("secretsmanager", region_name=settings.aws_region)
    
    db = json.loads(
        client.get_secret_value(
            SecretId="paycore/internal/db"
        )["SecretString"]
    )

    config = json.loads(
        client.get_secret_value(
            SecretId="paycore/internal/config"
        )["SecretString"]
    )

    return {**db, **config}

secrets = load_secrets()

DATABASE_URL = f"postgresql://{secrets["db_username"]}:{secrets["db_password"]}@database:5432/paycore"
SECRET_KEY = secrets["secret_key"]
CLOUDFLARE_TOKEN = secrets["cloudflare_token"]
CALLBACK_API_KEY = secrets["callback_api_key"]

