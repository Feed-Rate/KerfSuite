"""
KerfCut — PDF Export
Generates a professional cut plan + cost summary PDF.
Requires: reportlab
"""
import datetime
from pathlib import Path
from xml.sax.saxutils import escape
from utils.logger import logger

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib import colors
    from reportlab.lib.units import mm
    from reportlab.platypus import (SimpleDocTemplate, Table, TableStyle,
                                    Paragraph, Spacer, HRFlowable, PageBreak)
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.graphics.shapes import Drawing, Rect as RLRect, String, Line, Group
    from reportlab.pdfbase.pdfmetrics import stringWidth
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False


class TableFactory:
    """Service to create standardized tables for the PDF report."""

    @staticmethod
    def create_stock_table(sheets: list) -> Table:
        data = [["Dimensions (mm)", "Available Qty", "Active"]]
        for s in sheets:
            data.append([f"{s.width} x {s.height}", str(s.quantity), "Yes" if s.active else "No"])

        t = Table(data, colWidths=[60*mm, 30*mm, 20*mm])
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f0f4f8")),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#fcfcfc")]),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cccccc")),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ]))
        return t

    @staticmethod
    def create_piece_table(pieces: list) -> Table:
        data = [["#", "Label", "Qty", "Width (mm)", "Height (mm)", "Rotate"]]
        for i, p in enumerate(pieces):
            if p.quantity > 0:
                data.append([str(i + 1), p.label or "—", str(p.quantity), str(p.width), str(p.height), "Yes" if p.can_rotate else "No"])

        t = Table(data, colWidths=[10*mm, 60*mm, 15*mm, 30*mm, 30*mm, 15*mm])
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2d6a9f")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f0f4f8")]),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cccccc")),
            ("ALIGN", (2, 0), (-1, -1), "CENTER"),
        ]))
        return t


class DrawingEngine:
    """Service to handle technical drawings on the PDF canvas."""

    def __init__(self, page_width: float = 175 * mm):
        self.page_w = page_width

    def draw_layout(self, layout, group_count: int) -> Drawing:
        flip = layout.sheet.height > layout.sheet.width
        disp_sw = layout.sheet.height if flip else layout.sheet.width
        disp_sh = layout.sheet.width if flip else layout.sheet.height

        scale = min(self.page_w / disp_sw, 100*mm / disp_sh)
        dw, dh = disp_sw * scale, disp_sh * scale
        m_top, m_right = 8*mm, 10*mm

        d = Drawing(dw + m_right, dh + m_top)
        d.add(RLRect(0, 0, dw, dh, fillColor=colors.HexColor("#eaeaea"), strokeColor=colors.black))

        self._draw_dimensions(d, dw, dh, disp_sw, disp_sh)
        self._draw_pieces(d, layout.placed, flip, scale, dh)

        return d

    def _draw_dimensions(self, d, dw, dh, sw, sh):
        # Width dim
        d.add(Line(0, dh + 3*mm, dw, dh + 3*mm, strokeWidth=0.5))
        w_str = str(sw)
        tw = stringWidth(w_str, "Helvetica", 7)
        d.add(String(dw/2 - tw/2, dh + 3.5*mm, w_str, fontSize=7))

        # Height dim
        d.add(Line(dw + 3*mm, 0, dw + 3*mm, dh, strokeWidth=0.5))
        h_str = str(sh)
        th = stringWidth(h_str, "Helvetica", 7)
        g = Group(String(0, 0, h_str, fontSize=7))
        g.translate(dw + 3.5*mm, dh/2 + th/2)
        g.rotate(-90)
        d.add(g)

    def _draw_pieces(self, d, placed, flip, scale, dh):
        for i, pp in enumerate(placed):
            pp_x, pp_y = (pp.y, pp.x) if flip else (pp.x, pp.y)
            pp_w, pp_h = (pp.height, pp.width) if flip else (pp.width, pp.height)

            x, w, h = pp_x * scale, pp_w * scale, pp_h * scale
            y = dh - (pp_y + pp_h) * scale

            d.add(RLRect(x, y, w, h, fillColor=colors.white, strokeWidth=0.5))

            # Label
            lbl = pp.piece.label or f"P{i+1}"
            f_size = max(5, min(7, int(h * 0.25)))
            lw = stringWidth(lbl, "Helvetica-Bold", f_size)
            if w > lw + 1*mm:
                d.add(String(x + w/2 - lw/2, y + h/2 - f_size/2.5, lbl, fontSize=f_size, fontName="Helvetica-Bold"))


class PDFReportBuilder:
    """Builder service to assemble the PDF report pages."""

    def __init__(self, job, filepath, currency="R"):
        self.job = job
        self.filepath = filepath
        self.currency = currency.strip()
        self.styles = getSampleStyleSheet()
        self.normal = self.styles["Normal"]
        self.h2 = ParagraphStyle("H2", parent=self.styles["Heading2"], fontSize=11, spaceAfter=2)
        self.story = []
        self.drawing_engine = DrawingEngine()

    def build(self):
        self._add_cover_page()
        self._add_statistics_page()
        self._add_cut_plans()

        doc = SimpleDocTemplate(
            self.filepath, pagesize=A4,
            leftMargin=15*mm, rightMargin=15*mm,
            topMargin=15*mm, bottomMargin=15*mm,
        )
        doc.build(self.story)

    def _add_header(self):
        date_str = datetime.date.today().strftime("%d.%m.%Y")
        data = [[self._job_info_table(), Paragraph(f"Date: {date_str}", self.normal)]]
        t = Table(data, colWidths=[130*mm, 50*mm])
        t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("ALIGN", (1, 0), (1, 0), "RIGHT")]))
        self.story.append(t)
        self.story.append(Spacer(1, 8*mm))

    def _job_info_table(self):
        rows = [[Paragraph("Job:", self.normal), Paragraph(escape(self.job.name), self.normal)]]
        if self.job.customer:
            rows.append([Paragraph("Customer:", self.normal), Paragraph(escape(self.job.customer), self.normal)])
        if self.job.material_name:
            rows.append([Paragraph("Material:", self.normal), Paragraph(escape(self.job.material_name), self.normal)])
        if self.job.notes:
            rows.append([Paragraph("Notes:", self.normal), Paragraph(escape(self.job.notes), self.normal)])

        t = Table(rows, colWidths=[20*mm, 100*mm])
        t.setStyle(TableStyle([("LINEBELOW", (1, 0), (1, -1), 0.5, colors.black), ("BOTTOMPADDING", (0,0), (-1,-1), 2)]))
        return t

    def _add_cover_page(self):
        self.story.append(Paragraph("Cut Plan Instructions", self.styles["Title"]))
        self._add_header()
        self.story.append(Paragraph("Stock Sheets Available", self.h2))
        self.story.append(TableFactory.create_stock_table(self.job.sheets))
        self.story.append(Spacer(1, 6*mm))
        self.story.append(Paragraph("Pieces Required", self.h2))
        self.story.append(TableFactory.create_piece_table(self.job.pieces))
        self.story.append(PageBreak())

    def _add_statistics_page(self):
        self.story.append(Paragraph("Job Statistics & Costs", self.styles["Title"]))
        self._add_header()
        # Summary Stats
        stats = [["Sheets used", str(self.job.sheets_used)], ["Overall efficiency", f"{self.job.overall_efficiency:.1f}%"]]
        self.story.append(Table(stats, colWidths=[60*mm, 60*mm]))
        # Costs
        if self.job.total_sell_price > 0:
            self.story.append(Spacer(1, 6*mm))
            self.story.append(Paragraph("Costs", self.h2))
            costs = [["Sell price", f"{self.currency} {self.job.total_sell_price:.2f}"]]
            self.story.append(Table(costs, colWidths=[60*mm, 60*mm]))
        self.story.append(PageBreak())

    def _add_cut_plans(self):
        from .models import group_identical_layouts
        groups = group_identical_layouts(self.job.layouts)
        for idx, group in enumerate(groups):
            self._add_header()
            layout = group.template
            self.story.append(Paragraph(f"Sheet {idx+1} ({group.count}x): {layout.sheet.width}x{layout.sheet.height}mm", self.h2))
            self.story.append(self.drawing_engine.draw_layout(layout, group.count))
            self.story.append(PageBreak())


def export_pdf(job, filepath: str, currency: str = "R") -> None:
    """Main entry point for PDF export."""
    if not REPORTLAB_AVAILABLE:
        raise ImportError("reportlab is required for PDF export.")

    builder = PDFReportBuilder(job, filepath, currency)
    builder.build()
