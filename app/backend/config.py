# Simply to handle loading our environment variables
from pydantic_settings import BaseSettings, SettingsConfigDict

import json
import os


# We keep pydantic for loading the env file
class Settings(BaseSettings):
    aws_region: str
    db_password: str
    db_username: str
    secret_key: str
    cloudflare_token: str
    callback_api_key: str


    model_config = SettingsConfigDict(
        env_file= ".env",
        env_file_encoding= "utf-8",
        extra= "ignore"
    )


settings = Settings()


DATABASE_URL = f"postgresql://{settings.db_username}:{settings.db_password}@database:5432/paycore"
SECRET_KEY = settings.secret_key
CLOUDFLARE_TOKEN = settings.cloudflare_token
CALLBACK_API_KEY = settings.callback_api_key

