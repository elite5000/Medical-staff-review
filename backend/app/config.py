import secrets

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.paths import get_data_dir, is_frozen


def _default_database_url() -> str:
    if is_frozen():
        return f"sqlite:///{get_data_dir() / 'data.db'}"
    return "sqlite:///./dev.db"


def _default_pairing_token() -> str | None:
    """None outside the packaged desktop build, so dev/test traffic is never gated.

    Packaged builds always enforce a token (see main.py's require_pairing_token
    middleware), persisted next to the DB so it survives restarts and previously paired
    devices don't need to re-scan the tray app's QR code.
    """
    if not is_frozen():
        return None
    token_path = get_data_dir() / "pairing_token.txt"
    if token_path.exists():
        persisted = token_path.read_text().strip()
        if persisted:
            return persisted
    token = secrets.token_urlsafe(32)
    token_path.write_text(token)
    return token


class Settings(BaseSettings):
    """Runtime configuration, overridable via environment variables (e.g. APP_DATABASE_URL)."""

    model_config = SettingsConfigDict(env_prefix="APP_")

    database_url: str = Field(default_factory=_default_database_url)
    pairing_token: str | None = Field(default_factory=_default_pairing_token)


settings = Settings()
