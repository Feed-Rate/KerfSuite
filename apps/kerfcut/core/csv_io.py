"""
KerfCut — CSV Input/Output
Handles parsing of pieces from CSV, and exporting pieces to CSV.
"""
import csv
import re
from .models import Piece
from utils.logger import logger

def _safe_int(val, field_name="value") -> int:
    """Safely convert string/float inputs to int, handling whitespace and decimals."""
    if not val: return 0
    try:
        # float(str(...)) handles "10.0" strings
        res = int(float(str(val).strip()))
        return res
    except (ValueError, TypeError):
        logger.warning(f"Invalid numeric value '{val}' for field '{field_name}'. Defaulting to 0.")
        return 0

def parse_pieces_from_csv(filepath: str, max_rows: int = 5000) -> list[Piece]:
    """
    Parse a CSV file and return a list of Piece objects.
    Raises ValueError or Exception if parsing fails or row limit exceeded.
    """
    pieces = []
    try:
        with open(filepath, newline="", encoding="utf-8-sig") as f:
            # Check if file is empty
            if f.read(1) == "":
                raise ValueError("The CSV file is empty.")
            f.seek(0)

            reader = csv.DictReader(f)

            normalized_fieldnames = {}
            if reader.fieldnames:
                for fn in reader.fieldnames:
                    if fn:
                        norm = re.sub(r'[^a-zA-Z0-9]', '', fn).lower()
                        normalized_fieldnames[norm] = fn
            else:
                raise ValueError("Could not parse CSV headers. Check file format.")

            def get_val(row_dict, *keys, default=""):
                for k in keys:
                    if k in normalized_fieldnames:
                        val = row_dict.get(normalized_fieldnames[k])
                        if val is not None and str(val).strip() != "":
                            return val
                return default

            for i, row in enumerate(reader):
                qty = _safe_int(get_val(row, "qty", "quantity", default=1), "Qty")
                w = _safe_int(get_val(row, "width", "w", "widthmm", default=0), "Width")
                h = _safe_int(get_val(row, "height", "h", "heightmm", default=0), "Height")
                label = get_val(row, "label", "name", default="")

                rot_val = str(get_val(row, "canrotate", "rotate", default="yes")).lower()
                rotate = rot_val not in ("no", "0", "false")

                # Validation: only add if physically meaningful
                if w > 0 and h > 0:
                    pieces.append(Piece(quantity=max(qty, 1), width=w, height=h, label=label, can_rotate=rotate))
                else:
                    logger.warning(f"Skipping row {i+1}: Invalid dimensions {w}x{h}.")

                if len(pieces) >= max_rows:
                    raise ValueError(
                        f"CSV import stopped: exceeded maximum of {max_rows} piece rows. "
                        f"Split your file or increase the limit."
                    )
    except FileNotFoundError:
        raise FileNotFoundError(f"File not found: {filepath}")
    except PermissionError:
        raise PermissionError(f"Permission denied: {filepath}")
    except UnicodeDecodeError:
        raise ValueError("Encoding error: Ensure the CSV is saved as UTF-8.")
    except Exception as e:
        if isinstance(e, ValueError): raise
        logger.error(f"Unexpected error parsing CSV: {e}", exc_info=True)
        raise Exception(f"Failed to parse CSV: {str(e)}")

    return pieces

def export_pieces_to_csv(pieces: list[Piece], filepath: str) -> None:
    """
    Export a list of pieces to a CSV file.
    """
    with open(filepath, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["#", "Label", "Qty", "Width (mm)", "Height (mm)", "Area (mm²)", "Can Rotate"])
        for i, p in enumerate(pieces):
            if p.quantity > 0:
                w.writerow([
                    i + 1,
                    p.label,
                    p.quantity,
                    p.width,
                    p.height,
                    str(p.area),
                    "Yes" if p.can_rotate else "No"
                ])
