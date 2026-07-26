from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, overridable via environment variables (e.g. APP_DATABASE_URL)."""

    model_config = SettingsConfigDict(env_prefix="APP_")

    database_url: str = "sqlite:///./dev.db"
    cors_origins: list[str] = ["http://localhost:5173"]


settings = Settings()
