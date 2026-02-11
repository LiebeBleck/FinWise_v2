from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # App
    APP_NAME: str = "FinWise API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 2

    # Database
    DATABASE_URL: str = "postgresql://finwise:finwise@localhost:5432/finwise"

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # Security
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS
    ALLOWED_ORIGINS: list = [
        "http://localhost",
        "http://localhost:3000",
        "https://yourdomain.com"
    ]

    # ML Models
    ML_MODELS_PATH: str = "app/ml/models"

    # FNS API (для чеков)
    FNS_API_KEY: Optional[str] = None
    FNS_API_URL: str = "https://proverkacheka.com/api/v1"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
