"""
KerfCut user data paths.
"""
import os
from pathlib import Path


APP_DATA_DIR = Path(
    os.getenv(
        "KERFCUT_DATA_DIR",
        str(Path.home() / "Documents" / "KerfSuite" / "KerfCut"),
    )
)
JOBS_DIR = APP_DATA_DIR / "jobs"
EXPORTS_DIR = APP_DATA_DIR / "exports"
LOGS_DIR = APP_DATA_DIR / "logs"


def ensure_user_dirs() -> None:
    """Create standard user-writable folders used by KerfCut."""
    for path in (JOBS_DIR, EXPORTS_DIR, LOGS_DIR):
        path.mkdir(parents=True, exist_ok=True)
