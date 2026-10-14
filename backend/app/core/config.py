import os

from pydantic_settings import BaseSettings
from pydantic import model_validator
from typing import Optional


class Settings(BaseSettings):
    # The application uses PostgreSQL in development and production. SQLite
    # is only allowed when explicitly running the isolated test environment.
    APP_ENV: str = "development"

    # Database
    DATABASE_URL: str = ""
    # Optional direct PostgreSQL URL for Alembic when DATABASE_URL uses a
    # serverless connection pool (for example, Neon’s pooled endpoint).
    MIGRATION_DATABASE_URL: Optional[str] = None
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # API
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "SignBridge Data Collection Tool"
    VERSION: str = "1.0.0"
    
    # Storage
    STORAGE_PATH: str = "./storage/videos"
    MAX_UPLOAD_SIZE: int = 100 * 1024 * 1024  # 100MB
    FACE_LANDMARKER_MODEL: str = "models/face_landmarker.task"
    HAND_LANDMARKER_MODEL: str = "models/hand_landmarker.task"
    ORIENTATION_SAMPLE_FPS: float = 4.0
    OBJECT_STORAGE_BUCKET: str = ""
    OBJECT_STORAGE_REGION: str = "auto"
    OBJECT_STORAGE_ENDPOINT_URL: Optional[str] = None
    OBJECT_STORAGE_PREFIX: str = "signbridge"
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    AWS_SESSION_TOKEN: Optional[str] = None
    
    # CORS
    BACKEND_CORS_ORIGINS: list = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8084",
        "http://127.0.0.1:8084",
    ]
    
    class Config:
        env_file = ".env"
        case_sensitive = True

    @model_validator(mode="after")
    def validate_production_configuration(self):
        environment = self.APP_ENV.strip().lower()
        if environment not in {"development", "test", "prod", "production"}:
            raise ValueError("APP_ENV must be development, test, or production")
        if os.getenv("K_SERVICE") and environment not in {"prod", "production"}:
            raise ValueError("Cloud Run requires APP_ENV=production")
        if environment == "test":
            if not self.DATABASE_URL:
                raise ValueError("DATABASE_URL must be set for tests")
            return self
        if not self.DATABASE_URL.strip().lower().startswith("postgresql"):
            raise ValueError("DATABASE_URL must point to PostgreSQL; SQLite is test-only")
        if environment not in {"prod", "production"}:
            return self

        problems = []
        if self.MIGRATION_DATABASE_URL and not self.MIGRATION_DATABASE_URL.strip().lower().startswith("postgresql"):
            problems.append("MIGRATION_DATABASE_URL must point to PostgreSQL")
        if (
            not self.SECRET_KEY
            or self.SECRET_KEY in {
                "your-secret-key-change-in-production",
                "replace-with-a-random-secret-at-least-32-characters-long",
            }
            or len(self.SECRET_KEY) < 32
        ):
            problems.append("SECRET_KEY must be a unique value of at least 32 characters")
        if not all((
            self.OBJECT_STORAGE_BUCKET,
            self.OBJECT_STORAGE_ENDPOINT_URL,
            self.AWS_ACCESS_KEY_ID,
            self.AWS_SECRET_ACCESS_KEY,
        )):
            problems.append("Cloudflare R2 credentials and bucket configuration are required")
        if not any(
            origin.strip()
            and "localhost" not in origin.lower()
            and "127.0.0.1" not in origin
            for origin in self.BACKEND_CORS_ORIGINS
        ):
            problems.append("BACKEND_CORS_ORIGINS must include the deployed web app origin")

        if problems:
            raise ValueError("Invalid production configuration: " + "; ".join(problems))
        return self


settings = Settings()
