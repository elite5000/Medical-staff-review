import os
import sys
from pathlib import Path

_APP_DATA_DIRNAME = "MedicalStaffReview"


def is_frozen() -> bool:
    """True when running as the PyInstaller-packaged desktop build, not `uv run`/pytest.

    Dev and test runs must never pick up the packaged-mode DB path or pairing-token
    enforcement, so every packaged-only default in app/config.py gates on this.
    """
    return getattr(sys, "frozen", False)


def get_data_dir() -> Path:
    """Per-user writable directory for the packaged app's DB and pairing token file.

    Only meaningful when is_frozen() is True — dev/test runs use the repo-relative ./dev.db.
    """
    base = os.environ.get("LOCALAPPDATA") or str(Path.home())
    data_dir = Path(base) / _APP_DATA_DIRNAME
    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir
