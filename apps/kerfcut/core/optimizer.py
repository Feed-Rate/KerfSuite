"""
KerfCut — MaxRects Bin-Packing Algorithm
"""
from __future__ import annotations
import copy
from abc import ABC, abstractmethod
from dataclasses import dataclass
from .models import Sheet, Piece, PlacedPiece, Job, SheetLayout, ensure_unique_job_ids


@dataclass
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def area(self):
        return self.w * self.h

    def contains(self, other: "Rect") -> bool:
        return (self.x <= other.x and self.y <= other.y and
                self.x + self.w >= other.x + other.w and
                self.y + self.h >= other.y + other.h)




class PackingStrategy(ABC):
    """Abstract base class for all cut optimization strategies."""

    @abstractmethod
    def pack_sheet(self, sheet: Sheet, pieces_flat: list[tuple["Piece", int]], kerf: int) -> tuple[list[PlacedPiece], list[tuple["Piece", int]]]:
        """
        Pack as many pieces as possible onto one sheet.
        Returns (placed_pieces, remaining_pieces)
        """
        pass


class MaxRectsBSSFStrategy(PackingStrategy):
    """
    MaxRects algorithm using Best Short Side Fit (BSSF) heuristic.
    Places each piece into the free rectangle that minimises the shorter leftover side.
    """

    def _split_rect(self, free: Rect, placed: Rect) -> list[Rect]:
        """Split a free rectangle around a placed rectangle — guillotine split."""
        result = []
        # Right of placed
        if placed.x + placed.w < free.x + free.w:
            result.append(Rect(
                placed.x + placed.w, free.y,
                free.x + free.w - (placed.x + placed.w), free.h
            ))
        # Above placed (top remainder)
        if placed.y + placed.h < free.y + free.h:
            result.append(Rect(
                free.x, placed.y + placed.h,
                free.w, free.y + free.h - (placed.y + placed.h)
            ))
        # Left of placed
        if free.x < placed.x:
            result.append(Rect(
                free.x, free.y,
                placed.x - free.x, free.h
            ))
        # Below placed
        if free.y < placed.y:
            result.append(Rect(
                free.x, free.y,
                free.w, placed.y - free.y
            ))
        return result

    def _prune_free_rects(self, free_rects: list[Rect]) -> list[Rect]:
        """Remove any free rectangle fully contained within another."""
        to_remove = set()
        n = len(free_rects)
        for i in range(n):
            if i in to_remove:
                continue
            a = free_rects[i]
            for j in range(i + 1, n):
                if j in to_remove:
                    continue
                b = free_rects[j]
                if a.contains(b):
                    to_remove.add(j)
                elif b.contains(a):
                    to_remove.add(i)
                    break
        return [r for i, r in enumerate(free_rects) if i not in to_remove]

    def _score_bssf(self, free: Rect, pw: int, ph: int) -> tuple[int, int]:
        """Best Short Side Fit score — lower is better."""
        leftover_x = free.w - pw
        leftover_y = free.h - ph
        short = min(leftover_x, leftover_y)
        long_ = max(leftover_x, leftover_y)
        return (short, long_)

    def pack_sheet(self, sheet: Sheet, pieces_flat: list[tuple["Piece", int]], kerf: int) -> tuple[list[PlacedPiece], list[tuple["Piece", int]]]:
        """
        Pack as many pieces as possible onto one sheet using MaxRects BSSF.
        """
        # Inflate the virtual sheet by kerf so that pieces at the edges
        # naturally "overflow" — the kerf beyond the sheet boundary is
        # just the saw blade cutting air, which is physically correct.
        free_rects = [Rect(0, 0, sheet.width + kerf, sheet.height + kerf)]
        placed_pieces: list[PlacedPiece] = []
        # Filter out invalid pieces upfront
        remaining = [p for p in pieces_flat if p[0].width > 0 and p[0].height > 0]

        # Sort by area descending for better packing
        remaining.sort(key=lambda x: x[0].width * x[0].height, reverse=True)

        changed = True
        while changed and remaining:
            changed = False
            best_score = (float('inf'), float('inf'))
            best_i = -1
            best_rect_i = -1
            best_pw = 0
            best_ph = 0
            best_rotated = False

            for i, (piece, _) in enumerate(remaining):

                for ri, free in enumerate(free_rects):
                    # Every piece reserves piece_dim + kerf in the virtual sheet
                    pw = piece.width + kerf
                    ph = piece.height + kerf

                    if pw <= free.w and ph <= free.h:
                        score = self._score_bssf(free, pw, ph)
                        if score < best_score:
                            best_score = score
                            best_i = i
                            best_rect_i = ri
                            best_pw = pw
                            best_ph = ph
                            best_rotated = False

                    # Try rotated
                    if piece.can_rotate:
                        pw2 = piece.height + kerf
                        ph2 = piece.width + kerf
                        if pw2 != pw or ph2 != ph:  # skip if same dimensions
                            if pw2 <= free.w and ph2 <= free.h:
                                score = self._score_bssf(free, pw2, ph2)
                                if score < best_score:
                                    best_score = score
                                    best_i = i
                                    best_rect_i = ri
                                    best_pw = pw2
                                    best_ph = ph2
                                    best_rotated = True

            if best_i == -1:
                break  # Nothing more fits

            piece, _ = remaining[best_i]
            free = free_rects[best_rect_i]
            placed = Rect(free.x, free.y, best_pw, best_ph)

            # Actual piece dimensions (without kerf for drawing)
            draw_w = piece.height if best_rotated else piece.width
            draw_h = piece.width if best_rotated else piece.height

            placed_pieces.append(PlacedPiece(
                piece=piece,
                x=free.x,
                y=free.y,
                width=draw_w,
                height=draw_h,
                rotated=best_rotated,
            ))

            # Split free rectangles
            new_free = []
            for ri, fr in enumerate(free_rects):
                # Check overlap with placed rect
                if not (placed.x >= fr.x + fr.w or
                        placed.x + placed.w <= fr.x or
                        placed.y >= fr.y + fr.h or
                        placed.y + placed.h <= fr.y):
                    new_free.extend(self._split_rect(fr, placed))
                else:
                    new_free.append(fr)

            free_rects = self._prune_free_rects(new_free)

            remaining.pop(best_i)
            changed = True

        return placed_pieces, remaining


class GuillotineStrategy(PackingStrategy):
    """
    Guillotine algorithm using MAXAS (Maximize Area of Split) heuristic.
    Enforces edge-to-edge cuts.
    """
    def _split_rect_guillotine(self, free: Rect, pw: int, ph: int) -> list[Rect]:
        """Split a free rectangle around a placed rectangle located at bottom-left (free.x, free.y) into exactly two non-overlapping rectangles."""
        w = free.w - pw
        h = free.h - ph

        area_horiz = max(w * ph, free.w * h)
        area_vert = max(pw * h, w * free.h)

        result = []
        if area_horiz > area_vert:
            # Horizontal split produces a larger single remaining chunk
            if w > 0 and ph > 0:
                result.append(Rect(free.x + pw, free.y, w, ph))
            if free.w > 0 and h > 0:
                result.append(Rect(free.x, free.y + ph, free.w, h))
        else:
            # Vertical split
            if pw > 0 and h > 0:
                result.append(Rect(free.x, free.y + ph, pw, h))
            if w > 0 and free.h > 0:
                result.append(Rect(free.x + pw, free.y, w, free.h))

        return result

    def pack_sheet(self, sheet: Sheet, pieces_flat: list[tuple["Piece", int]], kerf: int) -> tuple[list[PlacedPiece], list[tuple["Piece", int]]]:
        # Inflate the virtual sheet by kerf (same approach as MaxRects)
        free_rects = [Rect(0, 0, sheet.width + kerf, sheet.height + kerf)]
        placed_pieces: list[PlacedPiece] = []
        remaining = [p for p in pieces_flat if p[0].width > 0 and p[0].height > 0]

        # Sort by area descending for better packing
        remaining.sort(key=lambda x: x[0].width * x[0].height, reverse=True)

        changed = True
        while changed and remaining:
            changed = False
            best_score = (float('inf'), float('inf'))
            best_i = -1
            best_rect_i = -1
            best_pw = 0
            best_ph = 0
            best_rotated = False

            for i, (piece, _) in enumerate(remaining):

                for ri, free in enumerate(free_rects):
                    # Every piece reserves piece_dim + kerf in the virtual sheet
                    pw = piece.width + kerf
                    ph = piece.height + kerf
                    if pw <= free.w and ph <= free.h:
                        leftover_x = free.w - pw
                        leftover_y = free.h - ph
                        score = (min(leftover_x, leftover_y), max(leftover_x, leftover_y))
                        if score < best_score:
                            best_score = score
                            best_i = i
                            best_rect_i = ri
                            best_pw = pw
                            best_ph = ph
                            best_rotated = False

                    # Try rotated
                    if piece.can_rotate:
                        pw2 = piece.height + kerf
                        ph2 = piece.width + kerf
                        if pw2 != pw or ph2 != ph:
                            if pw2 <= free.w and ph2 <= free.h:
                                leftover_x = free.w - pw2
                                leftover_y = free.h - ph2
                                score = (min(leftover_x, leftover_y), max(leftover_x, leftover_y))
                                if score < best_score:
                                    best_score = score
                                    best_i = i
                                    best_rect_i = ri
                                    best_pw = pw2
                                    best_ph = ph2
                                    best_rotated = True

            if best_i == -1:
                break

            piece, _ = remaining[best_i]
            free = free_rects[best_rect_i]

            draw_w = piece.height if best_rotated else piece.width
            draw_h = piece.width if best_rotated else piece.height

            placed_pieces.append(PlacedPiece(
                piece=piece,
                x=free.x,
                y=free.y,
                width=draw_w,
                height=draw_h,
                rotated=best_rotated,
            ))

            new_free = self._split_rect_guillotine(free, best_pw, best_ph)
            free_rects.pop(best_rect_i)
            free_rects.extend(new_free)

            remaining.pop(best_i)
            changed = True

        return placed_pieces, remaining

# Distinct colors for pieces
PIECE_COLORS = [
    (100, 149, 237),  # cornflower blue
    (144, 238, 144),  # light green
    (255, 182, 193),  # light pink
    (255, 218, 185),  # peach
    (221, 160, 221),  # plum
    (135, 206, 235),  # sky blue
    (255, 255, 153),  # light yellow
    (188, 143, 143),  # rosy brown
    (152, 251, 152),  # pale green
    (173, 216, 230),  # light blue
    (255, 160, 122),  # light salmon
    (240, 230, 140),  # khaki
]


def _estimate_labor(layouts: list) -> tuple[float, float]:
    """Calculate estimated labor minutes and cost."""
    sheets_count = len(layouts)
    pieces_count = sum(len(l.placed) for l in layouts)
    minutes = (sheets_count * 5.0) + (pieces_count * 1.0)
    return minutes, 0.0  # cost calculated by caller using hourly rate


class BinPacker:
    """Service to orchestrate the bin-packing optimization process."""

    def __init__(self, job: "Job", strategy: PackingStrategy):
        self.job = job
        self.strategy = strategy
        self.sheet_pool: dict[int, tuple[Sheet, int]] = {}
        self.pieces_flat: list[tuple[Piece, int]] = []
        self.color_map: dict[str, tuple] = {}
        self.remaining: list[tuple[Piece, int]] = []
        self.used_sheet_ids: set[int] = set()

    def run(self) -> None:
        """Execute the optimization and populate job results."""
        self._initialize_pools()
        self._pack_all_sheets()
        self._finalize_results()

    def _initialize_pools(self) -> None:
        """Prepare sheet and piece pools for optimization."""
        self.job.layouts = []
        self.job.unplaced = []

        # Initialize sheet pool
        for i, sheet in enumerate(self.job.sheets):
            if sheet.active and sheet.width > 0 and sheet.height > 0:
                qty = max(sheet.quantity, 0)
                if qty > 0:
                    self.sheet_pool[i] = (sheet, qty)

        # Expand pieces and assign colors
        for idx, piece in enumerate(self.job.pieces):
            if piece.quantity > 0 and piece.width > 0 and piece.height > 0:
                self.color_map[piece.id] = PIECE_COLORS[idx % len(PIECE_COLORS)]
                for _ in range(piece.quantity):
                    self.pieces_flat.append((piece, idx))

        self.remaining = list(self.pieces_flat)

    def _pack_all_sheets(self) -> None:
        """Iteratively pack pieces onto sheets until no more fit or no more sheets."""
        while self.remaining and self.sheet_pool:
            best_fit = self._find_best_fit_layout()
            if not best_fit:
                break

            layout, sid, leftover = best_fit
            self._record_layout(layout, leftover, sid)

    def _find_best_fit_layout(self) -> tuple[SheetLayout, int, list] | None:
        """Find the best sheet/layout for current remaining pieces."""
        best_data = None
        best_efficiency = -1.0
        best_waste = float('inf')

        # Two-phase selection: Phase 1 (prefer used), Phase 2 (any)
        for prefer_used in (True, False):
            for sid, (sheet, qty) in self.sheet_pool.items():
                if prefer_used and sid not in self.used_sheet_ids:
                    continue

                placed, leftover = self.strategy.pack_sheet(sheet, list(self.remaining), self.job.blade_kerf)
                if not placed:
                    continue

                eff, waste = self._score_layout(sheet, placed)

                if self._is_better_layout(eff, waste, best_efficiency, best_waste):
                    best_efficiency, best_waste = eff, waste
                    best_data = (SheetLayout(sheet=sheet, placed=placed), sid, leftover)

            if best_data:
                break

        return best_data

    def _score_layout(self, sheet: Sheet, placed: list[PlacedPiece]) -> tuple[float, int]:
        """Calculate efficiency and waste for a proposed layout."""
        used_area = sum(p.width * p.height for p in placed)
        eff = used_area / sheet.area if sheet.area > 0 else 0
        waste = sheet.area - used_area
        return eff, waste

    def _is_better_layout(self, eff, waste, best_eff, best_waste) -> bool:
        """Tie-breaking logic for layout selection."""
        return (eff > best_eff + 1e-9 or (abs(eff - best_eff) <= 1e-9 and waste < best_waste))

    def _record_layout(self, layout: SheetLayout, leftover: list, sid: int) -> None:
        """Update state after a layout is selected."""
        for pp in layout.placed:
            pp.color = self.color_map.get(pp.piece.id, (180, 180, 180))

        layout.waste_area = layout.sheet.area - layout.used_area
        self.job.layouts.append(layout)
        self.remaining = leftover
        self.used_sheet_ids.add(sid)

        # Consume sheet
        sheet_obj, qty = self.sheet_pool[sid]
        if qty <= 1:
            del self.sheet_pool[sid]
        else:
            self.sheet_pool[sid] = (sheet_obj, qty - 1)

    def _finalize_results(self) -> None:
        """Consolidate unplaced pieces and update job statistics."""
        unplaced_dict = {}
        for p, _ in self.remaining:
            if p.id not in unplaced_dict:
                p_copy = copy.copy(p)
                p_copy.quantity = 0
                unplaced_dict[p.id] = p_copy
            unplaced_dict[p.id].quantity += 1

        self.job.unplaced = list(unplaced_dict.values())

        # Labor estimation
        mins, _ = _estimate_labor(self.job.layouts)
        self.job.estimated_labor_minutes = mins
        if self.job.hourly_rate > 0:
            self.job.estimated_labor_cost = (mins / 60.0) * self.job.hourly_rate
        else:
            self.job.estimated_labor_cost = 0.0


def optimize(job: "Job", strategy: PackingStrategy | None = None) -> "Job":
    """Main entry point for optimization logic."""
    if strategy is None:
        strategy = MaxRectsBSSFStrategy()

    ensure_unique_job_ids(job)

    packer = BinPacker(job, strategy)
    packer.run()

    return job
