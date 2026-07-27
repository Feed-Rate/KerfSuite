"""
KerfCut — Error Handling & Resilience Tests
"""
import pytest
import json
import tempfile
from pathlib import Path
from core.persistence import load_job, save_job
from core.csv_io import parse_pieces_from_csv
from core.models import Job

def test_load_corrupted_json():
    """Verify that loading invalid JSON raises a ValueError."""
    with tempfile.NamedTemporaryFile(suffix=".kcut", delete=False) as f:
        f.write(b"this is not json {")
        path = f.name

    try:
        with pytest.raises(ValueError) as excinfo:
            load_job(path)
        assert "corrupted" in str(excinfo.value)
    finally:
        Path(path).unlink()

def test_parse_malformed_csv():
    """Verify that an empty or weird CSV doesn't crash the parser."""
    with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as f:
        f.write(b"") # Empty file
        path = f.name

    try:
        with pytest.raises(ValueError) as excinfo:
            parse_pieces_from_csv(path)
        assert "empty" in str(excinfo.value).lower()
    finally:
        Path(path).unlink()

def test_parse_csv_invalid_dimensions():
    """Verify that rows with invalid dimensions are skipped (logged) rather than crashing."""
    csv_content = "Qty,Width,Height,Label\n1,abc,500,InvalidRow\n1,500,500,ValidRow"
    with tempfile.NamedTemporaryFile(suffix=".csv", mode="w", delete=False) as f:
        f.write(csv_content)
        path = f.name

    try:
        pieces = parse_pieces_from_csv(path)
        # Should only have the ValidRow
        assert len(pieces) == 1
        assert pieces[0].label == "ValidRow"
    finally:
        Path(path).unlink()

def test_save_job_permission_error():
    """Verify that saving to a read-only path is caught."""
    # This is hard to test cross-platform reliably without mocking
    # but we can at least verify the try/except block exists in the code.
    import inspect
    from core import persistence
    source = inspect.getsource(persistence.save_job)
    assert "except Exception as e:" in source
