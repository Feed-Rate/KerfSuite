"""
KerfCut — Authentication & Licensing
Handles secure communication with Supabase for license verification.
"""
import os
import sys
import httpx
import json
import time
import secrets
import base64
import uuid
import hashlib
from cryptography.fernet import Fernet
from PyQt6.QtCore import QSettings
from dotenv import load_dotenv
from utils.logger import logger
from version import APP_NAME, APP_AUTHOR

# Some terminal setups export SSLKEYLOGFILE to a virtual path that is not writable.
# Python's ssl.create_default_context() then raises PermissionError before any request.
os.environ.pop("SSLKEYLOGFILE", None)

# Load environment variables from .env (only used for local dev overrides)
load_dotenv()

API_BASE_URL = os.getenv("API_BASE_URL", "https://synontech.vercel.app/kerfsuite/api/v1")

# Trial limits
TRIAL_MAX_DAYS = 30  # Display only; enforcement is server-side
TRIAL_MAX_RUNS = 20


def force_trial_mode_enabled() -> bool:
    """Developer override: force app to behave as trial mode."""
    return os.getenv("KERFCUT_FORCE_TRIAL", "").lower() in {"1", "true", "yes"}


def _cache_trial_status(tier: str, runs_left: int, days_left: int):
    """Persist trial state for offline fallback."""
    settings = QSettings(APP_AUTHOR, APP_NAME)
    settings.setValue("trial/cached_tier", tier)
    settings.setValue("trial/cached_runs_left", runs_left)
    settings.setValue("trial/cached_days_left", days_left)


def dev_license_enabled() -> bool:
    """Allow the local dev key only during source-based development runs."""
    enabled = os.getenv("KERFCUT_DEV_LICENSE", "").lower() in {"1", "true", "yes"}
    return enabled and not getattr(sys, "frozen", False)

def _get_install_secret() -> bytes:
    """Get or create a per-install secret for offline token encryption."""
    settings = QSettings(APP_AUTHOR, APP_NAME)
    secret_hex = settings.value("auth/install_secret", "", type=str)
    if not secret_hex:
        secret_hex = secrets.token_hex(32)
        settings.setValue("auth/install_secret", secret_hex)
    return secret_hex.encode("utf-8")

def _get_fernet() -> Fernet:
    """Derive the encryption key from machine identity and a per-install secret."""
    install_secret = _get_install_secret()
    mac = str(uuid.getnode()).encode("utf-8")
    digest = hashlib.sha256(install_secret + mac).digest()
    key = base64.urlsafe_b64encode(digest)
    return Fernet(key)

def _get_machine_id() -> str:
    """Generate a unique, stable composite hardware fingerprint.

    Combines multiple hardware identifiers to make spoofing significantly
    harder than a MAC-only approach.  Each component is read via subprocess
    with a short timeout; if any source fails the fingerprint degrades
    gracefully (the remaining components still produce a deterministic hash).

    Sources:
      1. MAC address         — trivial to spoof alone, but stable across OS reinstalls.
      2. Windows Machine SID — hard to change without breaking the OS install.
      3. Boot disk serial    — manufacturer-assigned, very hard to fake.
    """
    import subprocess

    components: list[str] = []

    # 1. MAC address (always available via uuid)
    components.append(str(uuid.getnode()))

    # Safely escape username for WMI/PowerShell queries
    safe_username = os.environ.get('USERNAME', '').replace("'", "''")

    # 2. Windows Machine SID (the domain prefix, not the per-user RID)
    try:
        result = subprocess.run(
            ["wmic", "useraccount", "where",
             f"name='{safe_username}'", "get", "sid"],
            capture_output=True, text=True, timeout=5,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        for line in result.stdout.strip().splitlines():
            line = line.strip()
            if line.startswith("S-"):
                # Strip the per-user RID to get the machine-level SID
                machine_sid = "-".join(line.split("-")[:-1])
                components.append(machine_sid)
                break
    except Exception:
        # Fallback: try PowerShell Get-CimInstance (wmic is deprecated on Win11)
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "(Get-CimInstance Win32_UserAccount -Filter "
                 f"\"Name='{safe_username}'\").SID"],
                capture_output=True, text=True, timeout=8,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            for line in result.stdout.strip().splitlines():
                line = line.strip()
                if line.startswith("S-"):
                    machine_sid = "-".join(line.split("-")[:-1])
                    components.append(machine_sid)
                    break
        except Exception:
            pass  # Both failed — omit this component

    # 3. Boot disk serial number
    try:
        result = subprocess.run(
            ["wmic", "diskdrive", "where", "Index=0", "get", "SerialNumber"],
            capture_output=True, text=True, timeout=5,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        lines = [l.strip() for l in result.stdout.strip().splitlines()
                 if l.strip() and l.strip().lower() != "serialnumber"]
        if lines:
            components.append(lines[0])
    except Exception:
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "(Get-CimInstance Win32_DiskDrive -Filter 'Index=0').SerialNumber"],
                capture_output=True, text=True, timeout=8,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            serial = result.stdout.strip()
            if serial:
                components.append(serial)
        except Exception:
            pass

    combined = "|".join(components)
    return hashlib.sha256(combined.encode()).hexdigest()[:16].upper()


def get_machine_id_display() -> str:
    """Return the machine ID formatted for display (XXXX-XXXX-XXXX-XXXX)."""
    mid = _get_machine_id()
    return "-".join([mid[i:i + 4] for i in range(0, 16, 4)])

def save_offline_token(license_key: str):
    """Saves an encrypted token valid for 30 days."""
    try:
        # 30 day grace period
        expiry = time.time() + (30 * 24 * 60 * 60)
        data = {
            "key": license_key,
            "expires_at": expiry,
            "machine_id": _get_machine_id()
        }
        encrypted = _get_fernet().encrypt(json.dumps(data).encode("utf-8"))
        
        settings = QSettings(APP_AUTHOR, APP_NAME)
        settings.setValue("auth/grace_token", encrypted.decode("utf-8"))
        # Record this to detect clock rollbacks
        settings.setValue("auth/last_verified", time.time())
        logger.info("Offline grace token saved.")
    except Exception as e:
        logger.error(f"Failed to save offline token: {e}", exc_info=True)

def check_offline_token() -> bool:
    """Checks if a valid, unexpired offline token exists for this machine."""
    if force_trial_mode_enabled():
        return False
    settings = QSettings(APP_AUTHOR, APP_NAME)
    
    # 1. Clock Tampering Check
    last_verified = float(settings.value("auth/last_verified", 0))
    current_time = time.time()
    
    if current_time < last_verified - 3600: # Allow 1 hour drift
        logger.warning("System clock appears to have been rolled back. Invalidating offline token.")
        return False

    token = settings.value("auth/grace_token", "")
    if not token:
        return False
        
    try:
        decrypted = _get_fernet().decrypt(token.encode("utf-8")).decode("utf-8")
        data = json.loads(decrypted)
        
        # 2. Expiry Check
        if time.time() > data.get("expires_at", 0):
            logger.warning("Offline grace token has expired.")
            return False
            
        # 3. Hardware Lock Check
        if data.get("machine_id") != _get_machine_id():
            logger.error("Offline token belongs to a different machine.")
            return False

        logger.info("Valid 30-day offline token found.")
        return True
    except Exception as e:
        logger.error(f"Offline token validation failed: {e}")
        return False


def get_license_info() -> dict:
    """Returns information about the current license status for UI display.
    Returns dict with keys: status, days_left, tier ('pro', 'trial', 'expired').
    """
    if dev_license_enabled():
        return {"status": "Developer", "days_left": 999, "tier": "pro"}

    if force_trial_mode_enabled():
        trial = get_trial_status()
        if trial["tier"] == "trial":
            runs_left = trial["runs_left"]
            return {
                "status": "Trial",
                "days_left": trial["days_left"],
                "runs_left": runs_left,
                "runs_used": max(0, TRIAL_MAX_RUNS - runs_left),
                "runs_total": TRIAL_MAX_RUNS,
                "tier": "trial"
            }
        return {"status": "Expired (Read-Only)", "days_left": 0, "tier": "expired"}
        
    settings = QSettings(APP_AUTHOR, APP_NAME)
    token = settings.value("auth/grace_token", "")
    
    # Check for active Pro license first
    if token:
        try:
            decrypted = _get_fernet().decrypt(token.encode("utf-8")).decode("utf-8")
            data = json.loads(decrypted)
            
            expires_at = data.get("expires_at", 0)
            remaining_seconds = expires_at - time.time()
            days_left = max(0, int(remaining_seconds / (24 * 60 * 60)))
            
            if data.get("machine_id") != _get_machine_id():
                return {"status": "Hardware Mismatch", "days_left": 0, "tier": "expired"}
            
            if remaining_seconds > 0:
                return {
                    "status": "Activated",
                    "days_left": days_left,
                    "key": data.get("key", "****"),
                    "tier": "pro"
                }
        except Exception as e:
            logger.warning(f"Failed to parse offline token: {e}")
    
    # No valid Pro license — check trial status
    trial = get_trial_status()
    if trial["tier"] == "trial":
        runs_left = trial["runs_left"]
        return {
            "status": "Trial",
            "days_left": trial["days_left"],
            "runs_left": runs_left,
            "runs_used": max(0, TRIAL_MAX_RUNS - runs_left),
            "runs_total": TRIAL_MAX_RUNS,
            "tier": "trial"
        }
    
    return {"status": "Expired (Read-Only)", "days_left": 0, "tier": "expired"}


def get_trial_status() -> dict:
    """
    Query KerfPortal for the current machine's trial record.
    Returns dict with keys: tier ('trial' or 'expired'), runs_left, days_left.
    """
    if not API_BASE_URL:
        logger.warning("No API credentials — defaulting to expired tier.")
        return {"tier": "expired", "runs_left": 0, "days_left": 0}
    
    current_mid = _get_machine_id()
    url = f"{API_BASE_URL}/trials/status"
    
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.get(url, params={"machine_id": current_mid})
            
            if response.status_code != 200:
                logger.error(f"Trial check failed: {response.status_code}")
                return {"tier": "expired", "runs_left": 0, "days_left": 0}
            
            data = response.json()
            tier = data.get("tier", "expired")
            if tier == "free":
                tier = "expired"
            
            trial_status = {
                "tier": tier,
                "runs_left": data.get("runs_left", 0),
                "days_left": data.get("days_left", 0)
            }
            _cache_trial_status(**trial_status)
            return trial_status
                
    except httpx.RequestError as e:
        logger.error(f"Network error checking trial: {e}")
        # Offline fallback — check local cache
        settings = QSettings(APP_AUTHOR, APP_NAME)
        cached_tier = settings.value("trial/cached_tier", "expired")
        if cached_tier == "free":
            cached_tier = "expired"
        cached_runs = int(settings.value("trial/cached_runs_left", 0))
        cached_days = int(settings.value("trial/cached_days_left", 0))
        return {"tier": cached_tier, "runs_left": cached_runs, "days_left": cached_days}
    except Exception as e:
        logger.error(f"Unexpected error in get_trial_status: {e}", exc_info=True)
        return {"tier": "expired", "runs_left": 0, "days_left": 0}


def increment_trial_run() -> bool:
    """
    Increment the trial run counter via KerfPortal API.
    Also caches the result locally for offline fallback.
    """
    if not API_BASE_URL:
        return False
    
    current_mid = _get_machine_id()
    url = f"{API_BASE_URL}/trials/run"
    
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(url, json={"machine_id": current_mid})
            if resp.status_code != 200:
                logger.error(f"Atomic trial increment failed: {resp.status_code} - {resp.text}")
                return False

            data = resp.json()
            tier = data.get("tier", "expired")
            if tier == "free":
                tier = "expired"
            runs_left = data.get("runs_left", 0)
            days_left = data.get("days_left", 0)
            
            _cache_trial_status(tier=tier, runs_left=runs_left, days_left=days_left)
            logger.info(f"Trial run incremented. {runs_left} runs left.")
            return True
    except Exception as e:
        logger.error(f"Failed to increment trial run: {e}")
        return False


def verify_license(license_key: str) -> bool:
    """
    Check the license against KerfPortal API.
    """
    # Development Bypass
    if license_key == "KERFCUT-DEV-99" and dev_license_enabled():
        logger.info("Development bypass key used.")
        save_offline_token(license_key)
        return True

    if force_trial_mode_enabled():
        logger.info("Trial mode forced via KERFCUT_FORCE_TRIAL; skipping license verification.")
        return False

    if not API_BASE_URL:
        logger.error("Licensing Error: Missing API_BASE_URL")
        return False
        
    current_mid = _get_machine_id()
    url = f"{API_BASE_URL}/licenses/verify"
    
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.post(url, json={"cdkey": license_key, "machine_id": current_mid})
            
            if response.status_code == 404:
                logger.warning("License key not found.")
                return False
                
            if response.status_code == 403:
                data = response.json()
                if data.get("status") == "revoked":
                    logger.warning("Access Denied: This license key has been revoked.")
                    settings = QSettings(APP_AUTHOR, APP_NAME)
                    settings.remove("auth/grace_token")
                    settings.remove("auth/last_verified")
                else:
                    logger.warning("Access Denied: License is bound to a different machine.")
                return False
                
            if response.status_code in (200, 201):
                logger.info("License verified via portal.")
                save_offline_token(license_key)
                return True
                
            logger.error(f"Portal check failed: {response.status_code} - {response.text}")
            return False
            
    except httpx.RequestError as e:
        logger.error(f"Network error during license check: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error in verify_license: {e}", exc_info=True)
        return False
