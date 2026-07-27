import pytest
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QMessageBox


@pytest.fixture
def app(qtbot, monkeypatch, tmp_path):
    monkeypatch.setenv("KERFCUT_DATA_DIR", str(tmp_path / "KerfCutData"))

    from ui.main_window import MainWindow
    # Monkeypatch auth BEFORE constructing MainWindow, so the status-bar
    # initialisation in __init__ never triggers a network call.
    from core import auth
    monkeypatch.setattr(auth, "get_license_info",
                        lambda: {"status": "Developer", "days_left": 999, "tier": "pro"})

    # Prevent QSettings from reading/writing the real Windows registry during tests.
    from PyQt6.QtCore import QSettings
    monkeypatch.setattr(QSettings, "value", lambda self, key, default=None, **kw: default)
    monkeypatch.setattr(QSettings, "setValue", lambda self, key, value: None)
    # Note: restoreGeometry lives on QMainWindow, not QSettings. Since value()
    # returns None above, geo=None in _restore_geometry() so restoreGeometry()
    # is never reached — no additional mock needed.

    # Avoid the unsaved-changes close dialog blocking teardown.
    monkeypatch.setattr(
        QMessageBox,
        "question",
        lambda *args, **kwargs: QMessageBox.StandardButton.Discard,
    )

    test_app = MainWindow()
    qtbot.addWidget(test_app)
    return test_app

def test_main_window_title(app):
    assert "KerfCut" in app.windowTitle()

def test_tab_navigation(app, qtbot):
    from ui.sheets_tab import SheetsTab
    from ui.pieces_tab import PiecesTab
    # Initial tab should be Job Info
    assert app.tabs.currentIndex() == 0

    # Click Stock Sheets tab
    # We can use the tab bar directly
    app.tabs.setCurrentIndex(1)
    assert isinstance(app.tabs.currentWidget(), SheetsTab)

    # Click Pieces tab
    app.tabs.setCurrentIndex(2)
    assert isinstance(app.tabs.currentWidget(), PiecesTab)

def test_add_sheet_workflow(app, qtbot):
    app.tabs.setCurrentIndex(1)
    sheets_tab = app.tabs.currentWidget()

    initial_rows = sheets_tab.table.rowCount()

    # Trigger "Add Sheet" action
    sheets_tab._add_sheet()

    assert sheets_tab.table.rowCount() == initial_rows + 1

def test_undo_redo_ui_integration(app, qtbot):
    """Adding a sheet and undoing/redoing should round-trip correctly."""
    app.tabs.setCurrentIndex(1)
    sheets_tab = app.tabs.currentWidget()

    # _add_sheet() internally calls mark_dirty() which pushes history.
    # We do NOT need to call mark_dirty() / _push_history() again ourselves;
    # doing so would push a duplicate snapshot and shift the undo index.
    sheets_tab._add_sheet()

    # After adding one sheet the table should have exactly 1 row.
    assert sheets_tab.table.rowCount() == 1

    # Undo should remove the sheet.
    app._undo()
    assert sheets_tab.table.rowCount() == 0

    # Redo should restore the sheet.
    app._redo()
    assert sheets_tab.table.rowCount() == 1

def test_optimization_trigger_validation(app, qtbot, monkeypatch):
    from PyQt6.QtWidgets import QMessageBox

    warnings = []
    def mock_warning(*args, **kwargs):
        for arg in args:
            if isinstance(arg, str):
                warnings.append(arg)
        return QMessageBox.StandardButton.Ok

    monkeypatch.setattr(QMessageBox, "warning", mock_warning)

    # Ensure sheets are empty
    app.job.sheets = []
    app.sheets_tab.load_from_job(app.job)

    app._run_optimize()
    assert any("Add at least one active stock sheet" in w for w in warnings)
