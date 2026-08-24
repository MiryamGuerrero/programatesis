import os
from functools import lru_cache
from typing import List
from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Obtener la ruta raíz del proyecto (donde debería estar el .env)
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
ENV_PATH = ROOT_DIR / ".env"
DEBUG_ENV_PATH = ROOT_DIR.parent / "debug" / "backend" / ".env"
ACTIVE_ENV_PATH = ENV_PATH if ENV_PATH.exists() else DEBUG_ENV_PATH

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(ACTIVE_ENV_PATH),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = Field(default="development", alias="APP_ENV")
    app_name: str = Field(default="Reuma Nutri API", alias="APP_NAME")
    app_host: str = Field(default="0.0.0.0", alias="APP_HOST")
    app_port: int = Field(default=8000, alias="APP_PORT")

    supabase_url: str = Field(default="", alias="SUPABASE_URL")
    supabase_anon_key: str = Field(default="", alias="SUPABASE_ANON_KEY")
    supabase_service_role_key: str = Field(default="", alias="SUPABASE_SERVICE_ROLE_KEY")
    supabase_jwt_secret: str = Field(default="", alias="SUPABASE_JWT_SECRET")
    onboarding_web_redirect_url: str = Field(
        default="http://localhost:3000",
        alias="ONBOARDING_WEB_REDIRECT_URL",
    )
    onboarding_tutor_redirect_url: str = Field(
        default="reumanutri://auth/callback",
        alias="ONBOARDING_TUTOR_REDIRECT_URL",
    )

    database_url: str = Field(default="", alias="DATABASE_URL")
    db_pool_min_size: int = Field(default=1, alias="DB_POOL_MIN_SIZE")
    db_pool_max_size: int = Field(default=0, alias="DB_POOL_MAX_SIZE")
    db_pool_workers: int = Field(default=0, alias="DB_POOL_WORKERS")
    cors_origins: List[str] | str = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://127.0.0.1:3000",
            "http://localhost:3001",
            "http://127.0.0.1:3001",
            "http://localhost:3002",
            "http://127.0.0.1:3002",
            "http://localhost:3003",
            "http://127.0.0.1:3003",
            "http://localhost:3004",
            "http://127.0.0.1:3004",
            "http://localhost:3005",
            "http://127.0.0.1:3005",
            "http://localhost:3006",
            "http://127.0.0.1:3006",
            "http://localhost:3007",
            "http://127.0.0.1:3007",
            "http://localhost:3008",
            "http://127.0.0.1:3008",
            "http://localhost:3009",
            "http://127.0.0.1:3009",
            "http://localhost:3010",
            "http://127.0.0.1:3010",
            "http://localhost:5173",
            "http://127.0.0.1:5173",
            "http://localhost:8080",
            "http://127.0.0.1:8080",
        ],
        alias="CORS_ORIGINS",
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def split_cors(cls, value: List[str] | str) -> List[str]:
        if isinstance(value, list):
            return value
        if not value:
            return []
        return [origin.strip() for origin in value.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
