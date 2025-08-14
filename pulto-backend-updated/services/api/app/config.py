
import os
from pydantic import BaseModel

def _truthy(val: str | None, default: bool) -> bool:
    if val is None:
        return default
    return val.strip().lower() in ("1", "true", "yes", "on")

class Settings(BaseModel):
    API_PORT: int = int(os.getenv("API_PORT", "8080"))
    JWT_SECRET: str = os.getenv("JWT_SECRET", "dev-secret-change-me")
    JWT_ISSUER: str = os.getenv("JWT_ISSUER", "pulto-backend")
    JWT_AUDIENCE: str = os.getenv("JWT_AUDIENCE", "pulto-clients")
    JWT_EXPIRES_MIN: int = int(os.getenv("JWT_EXPIRES_MIN", "1440"))

    # Feature flags
    ENABLE_APPLE_LOGIN: bool = _truthy(os.getenv("ENABLE_APPLE_LOGIN"), False)
    ENABLE_DEV_LOGIN: bool = _truthy(os.getenv("ENABLE_DEV_LOGIN"), True)

    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "pulto")
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "pulto")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "pulTopass")
    POSTGRES_HOST: str = os.getenv("POSTGRES_HOST", "db")
    POSTGRES_PORT: int = int(os.getenv("POSTGRES_PORT", "5432"))

    REDIS_URL: str = os.getenv("REDIS_URL", "redis://redis:6379/0")

    S3_ENDPOINT: str = os.getenv("S3_ENDPOINT", "http://minio:9000")
    S3_ACCESS_KEY: str = os.getenv("S3_ACCESS_KEY", "minio")
    S3_SECRET_KEY: str = os.getenv("S3_SECRET_KEY", "minio12345")
    S3_BUCKET_ASSETS: str = os.getenv("S3_BUCKET_ASSETS", "pulto-assets")
    S3_BUCKET_NOTEBOOKS: str = os.getenv("S3_BUCKET_NOTEBOOKS", "pulto-notebooks")
    S3_REGION: str = os.getenv("S3_REGION", "us-east-1")

    MQTT_BROKER_HOST: str = os.getenv("MQTT_BROKER_HOST", "mqtt")
    MQTT_BROKER_PORT: int = int(os.getenv("MQTT_BROKER_PORT", "1883"))

    APPLE_TEAM_ID: str = os.getenv("APPLE_TEAM_ID", "").strip()
    APPLE_CLIENT_ID: str = os.getenv("APPLE_CLIENT_ID", "").strip()
    APPLE_KEY_ID: str = os.getenv("APPLE_KEY_ID", "").strip()
    APPLE_PRIVATE_KEY: str = os.getenv("APPLE_PRIVATE_KEY", "").strip()

    @property
    def apple_login_effective(self) -> bool:
        return self.ENABLE_APPLE_LOGIN and bool(self.APPLE_CLIENT_ID)

settings = Settings()
