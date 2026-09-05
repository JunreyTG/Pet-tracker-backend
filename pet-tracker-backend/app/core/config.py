from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Pet Tracker Backend"
    app_version: str = "0.1.0"
    debug: bool = False
    firebase_credentials_path: Path = Path(".credentials/firebase-service-account.json")
    firebase_project_id: str | None = None
    device_offline_threshold_seconds: int = Field(default=300, gt=0)
    low_battery_threshold_percent: int = Field(default=20, ge=0, le=100)

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
