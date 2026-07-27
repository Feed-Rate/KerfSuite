"""
KerfCut — Job Persistence (JSON)
Saves/loads .zcad files and imports legacy Z-CAD .ZAD files.
"""
import json
import uuid
from datetime import datetime
from pathlib import Path
from .models import Job, Sheet, Piece, PlacedPiece, SheetLayout, ensure_unique_job_ids
from .paths import JOBS_DIR
from utils.logger import logger

# Standard user-writable jobs folder.
DEFAULT_JOBS_DIR = JOBS_DIR


def _id_or_new(value: str | None) -> str:
    return value or str(uuid.uuid4())


def job_to_dict(job: Job) -> dict:
    ensure_unique_job_ids(job)
    return {
        "version": "1.0",
        "app": "KerfCut",
        "saved_at": datetime.now().isoformat(),
        "name": job.name,
        "customer": job.customer,
        "notes": job.notes,
        "material_name": job.material_name,
        "blade_kerf": job.blade_kerf,
        "markup_percent": job.markup_percent,
        "hourly_rate": job.hourly_rate,
        "estimated_labor_cost": job.estimated_labor_cost,
        "estimated_labor_minutes": job.estimated_labor_minutes,
        "cut_mode": job.cut_mode,
        "sheets": [
            {
                "id": s.id,
                "width": s.width,
                "height": s.height,
                "active": s.active,
                "quantity": s.quantity,
                "buy_price": s.buy_price,
                "sell_price": s.sell_price,
                "thickness": s.thickness,
                "label": s.label,
            }
            for s in job.sheets
        ],
        "pieces": [
            {
                "id": p.id,
                "quantity": p.quantity,
                "width": p.width,
                "height": p.height,
                "can_rotate": p.can_rotate,
                "label": p.label,
            }
            for p in job.pieces
        ],
        "unplaced": [
            {
                "id": p.id,
                "quantity": p.quantity,
                "width": p.width,
                "height": p.height,
                "can_rotate": p.can_rotate,
                "label": p.label,
            }
            for p in job.unplaced
        ],
        "layouts": [
            {
                "sheet": {
                    "id": l.sheet.id,
                    "width": l.sheet.width,
                    "height": l.sheet.height,
                    "active": l.sheet.active,
                    "quantity": l.sheet.quantity,
                    "buy_price": l.sheet.buy_price,
                    "sell_price": l.sheet.sell_price,
                    "thickness": l.sheet.thickness,
                    "label": l.sheet.label,
                },
                "placed": [
                    {
                        "piece": {
                            "id": p.piece.id,
                            "quantity": p.piece.quantity,
                            "width": p.piece.width,
                            "height": p.piece.height,
                            "can_rotate": p.piece.can_rotate,
                            "label": p.piece.label,
                        },
                        "x": p.x,
                        "y": p.y,
                        "width": p.width,
                        "height": p.height,
                        "rotated": p.rotated,
                        "color": list(p.color),
                    }
                    for p in l.placed
                ],
                "waste_area": l.waste_area,
            }
            for l in job.layouts
        ],
    }


def job_from_dict(data: dict) -> Job:
    version = data.get("version", "1.0")
    if version not in ("1.0",):
        logger.warning(f"Unknown file version: {version}. Data may be corrupted.")

    job = Job(
        name=data.get("name", ""),
        customer=data.get("customer", ""),
        notes=data.get("notes", ""),
        material_name=data.get("material_name", ""),
        blade_kerf=data.get("blade_kerf", 4),
        markup_percent=data.get("markup_percent", 0.0),
        hourly_rate=data.get("hourly_rate", 0.0),
        estimated_labor_cost=data.get("estimated_labor_cost", 0.0),
        estimated_labor_minutes=data.get("estimated_labor_minutes", 0.0),
        cut_mode=data.get("cut_mode", "nested"),
    )
    for s in data.get("sheets", []):
        job.sheets.append(Sheet(
            id=_id_or_new(s.get("id")),
            width=s.get("width", 0),
            height=s.get("height", 0),
            active=s.get("active", True),
            quantity=s.get("quantity", 1),
            buy_price=s.get("buy_price", 0.0),
            sell_price=s.get("sell_price", 0.0),
            thickness=s.get("thickness", 0.0),
            label=s.get("label", ""),
        ))
    for p in data.get("pieces", []):
        can_rot = p.get("can_rotate", True)
        # Migrate legacy grain_locked to can_rotate
        if p.get("grain_locked") is True:
            can_rot = False

        job.pieces.append(Piece(
            id=_id_or_new(p.get("id")),
            quantity=p.get("quantity", 0),
            width=p.get("width", 0),
            height=p.get("height", 0),
            can_rotate=can_rot,
            label=p.get("label", ""),
        ))
    for p in data.get("unplaced", []):
        can_rot = p.get("can_rotate", True)
        if p.get("grain_locked") is True:
            can_rot = False

        job.unplaced.append(Piece(
            id=_id_or_new(p.get("id")),
            quantity=p.get("quantity", 0),
            width=p.get("width", 0),
            height=p.get("height", 0),
            can_rotate=can_rot,
            label=p.get("label", ""),
        ))
    for l_data in data.get("layouts", []):
        s_data = l_data.get("sheet", {})
        sheet = Sheet(
            id=_id_or_new(s_data.get("id")),
            width=s_data.get("width", 0),
            height=s_data.get("height", 0),
            active=s_data.get("active", True),
            quantity=s_data.get("quantity", 1),
            buy_price=s_data.get("buy_price", 0.0),
            sell_price=s_data.get("sell_price", 0.0),
            thickness=s_data.get("thickness", 0.0),
            label=s_data.get("label", ""),
        )
        layout = SheetLayout(sheet=sheet, waste_area=l_data.get("waste_area", 0))
        for p_data in l_data.get("placed", []):
            piece_data = p_data.get("piece", {})
            can_rot = piece_data.get("can_rotate", True)
            if piece_data.get("grain_locked") is True:
                can_rot = False
            piece = Piece(
                id=_id_or_new(piece_data.get("id")),
                quantity=piece_data.get("quantity", 0),
                width=piece_data.get("width", 0),
                height=piece_data.get("height", 0),
                can_rotate=can_rot,
                label=piece_data.get("label", ""),
            )
            color_data = p_data.get("color", [100, 149, 237])
            placed_piece = PlacedPiece(
                piece=piece,
                x=p_data.get("x", 0),
                y=p_data.get("y", 0),
                width=p_data.get("width", 0),
                height=p_data.get("height", 0),
                rotated=p_data.get("rotated", False),
                color=tuple(color_data)
            )
            layout.placed.append(placed_piece)
        job.layouts.append(layout)
    ensure_unique_job_ids(job)
    return job


def save_job(job: Job, filepath: str) -> None:
    """Save a Job to disk in .kcut format."""
    try:
        Path(filepath).parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(job_to_dict(job), f, indent=2, ensure_ascii=False)
    except Exception as e:
        logger.error(f"Failed to save job to {filepath}: {e}", exc_info=True)
        raise


def load_job(filepath: str) -> Job:
    """Load a .kcut or .zcad Job from disk."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        return job_from_dict(data)
    except json.JSONDecodeError:
        logger.error(f"Failed to decode job file (invalid JSON): {filepath}")
        raise ValueError("Selected file is corrupted or not a valid KerfCut job.")
    except Exception as e:
        logger.error(f"Error loading job from {filepath}: {e}", exc_info=True)
        raise


class LegacyZADImporter:
    """Service to parse legacy Z-CAD .ZAD files."""

    def __init__(self, filepath: str):
        self.filepath = Path(filepath)
        self.job = Job(name=self.filepath.stem)
        self.dispatch_map = {
            "Material:": self._parse_material,
            "Mat.\t": self._parse_stock,
            "Auftrag:": self._parse_customer,
            "Sonstiges:": self._parse_notes,
            "Pos.\t": self._parse_piece,
        }

    def run(self) -> Job:
        """Parse the file and return a Job object."""
        try:
            with open(self.filepath, "rb") as f:
                content = f.read().decode("latin-1")

            for line in content.replace("\r\n", "\n").split("\n"):
                self._dispatch_line(line)

            return self.job
        except Exception as e:
            logger.error(f"ZAD Import failed for {self.filepath}: {e}")
            raise

    def _dispatch_line(self, line: str) -> None:
        for prefix, method in self.dispatch_map.items():
            if line.startswith(prefix):
                method(line.split("\t"))
                return

    def _parse_material(self, parts: list[str]) -> None:
        if len(parts) > 1:
            self.job.material_name = parts[1].strip()

    def _parse_stock(self, parts: list[str]) -> None:
        if len(parts) >= 7 and parts[2].strip() == "1":
            try:
                w = int(parts[4]) if parts[4].strip() not in ("", "0") else 0
                h = int(parts[5]) if parts[5].strip() not in ("", "0") else 0
                if w > 0 and h > 0:
                    sheet = Sheet(width=w, height=h, active=True)
                    if len(parts) >= 12:
                        sheet.buy_price = float(parts[7])
                        sheet.sell_price = float(parts[8])
                        sheet.thickness = float(parts[9])
                        if self.job.blade_kerf == 4:
                            self.job.blade_kerf = int(parts[10])
                    self.job.sheets.append(sheet)
            except (ValueError, IndexError):
                pass

    def _parse_customer(self, parts: list[str]) -> None:
        if len(parts) > 1:
            self.job.customer = parts[1].strip()

    def _parse_notes(self, parts: list[str]) -> None:
        if len(parts) > 1:
            self.job.notes = parts[1].strip()

    def _parse_piece(self, parts: list[str]) -> None:
        if len(parts) >= 5:
            try:
                qty, w, h = int(parts[2]), int(parts[3]), int(parts[4].strip())
                if qty > 0 and w > 0 and h > 0:
                    self.job.pieces.append(Piece(quantity=qty, width=w, height=h))
            except ValueError:
                pass


def load_zad_file(filepath: str) -> Job:
    """Import a legacy Z-CAD .ZAD file into a KerfCut Job."""
    importer = LegacyZADImporter(filepath)
    return importer.run()


def get_recent_jobs(jobs_dir: str | None = None, max_count: int = 10) -> list[dict]:
    """Return list of recent .kcut and legacy .zcad files sorted by modification time."""
    path = Path(jobs_dir) if jobs_dir else DEFAULT_JOBS_DIR
    if not path.exists():
        return []
    files = list(path.glob("*.kcut")) + list(path.glob("*.zcad"))
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return [
        {
            "path": str(f),
            "name": f.stem,
            "modified": datetime.fromtimestamp(f.stat().st_mtime).strftime("%d.%m.%Y %H:%M"),
        }
        for f in files[:max_count]
    ]
