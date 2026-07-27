"""
KerfCut centralized logging.
Handles all application logging, including rotating file handlers.
"""
import logging
import os
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOGS_DIR = Path(
    os.getenv(
        "KERFCUT_DATA_DIR",
        str(Path.home() / "Documents" / "KerfSuite" / "KerfCut"),
    )
) / "logs"

# Setup logs directory
try:
    LOGS_DIR.mkdir(exist_ok=True, parents=True)
    LOG_FILE = LOGS_DIR / "app.log"
    can_write_logs = True
except Exception:
    can_write_logs = False

# Create a custom logger
logger = logging.getLogger("KerfCut")
logger.setLevel(logging.DEBUG)  # Capture everything, handlers will filter

# Prevent logging from propagating to the root logger multiple times
logger.propagate = False

if not logger.handlers:
    # 1. Console Handler (for dev)
    c_handler = logging.StreamHandler()
    c_handler.setLevel(logging.INFO)
    c_format = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%H:%M:%S')
    c_handler.setFormatter(c_format)
    logger.addHandler(c_handler)

    # 2. File Handler (Rotating, max 5MB, keep 3 backups)
    if can_write_logs:
        try:
            f_handler = RotatingFileHandler(LOG_FILE, maxBytes=5*1024*1024, backupCount=3, encoding='utf-8')
            f_handler.setLevel(logging.DEBUG)
            f_format = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s')
            f_handler.setFormatter(f_format)
            logger.addHandler(f_handler)
        except Exception as e:
            logger.warning(f"Could not initialize file logger: {e}. Running with console logging only.")
    else:
        logger.warning("Could not create logs directory. Running with console logging only.")

logger.info("Logger initialized.")
