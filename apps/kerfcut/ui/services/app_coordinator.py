from PyQt6.QtCore import QObject, pyqtSignal
from PyQt6.QtWidgets import QMessageBox, QFileDialog
import os
from core.models import Job
from core.persistence import DEFAULT_JOBS_DIR

class AppCoordinator(QObject):
    """Workflow coordinator. Handles interactions between UI and services."""

    status_message = pyqtSignal(str)

    def __init__(self, main_window, job_service, history_service):
        super().__init__()
        self.win = main_window
        self.job_service = job_service
        self.history_service = history_service

    def new_job(self):
        if self._confirm_discard():
            self.win.current_file = None
            self.job_service.job = Job()
            self.history_service.clear()
            # _push_history() calls collect_from_ui() first, ensuring the snapshot
            # reflects the freshly-loaded UI state (not stale widget data).
            self.win._push_history()
            self.job_service.set_dirty(False)
            self.history_service.mark_saved()
            self.win._update_title()
            self.status_message.emit("New job created.")

    def open_job(self):
        path, _ = QFileDialog.getOpenFileName(
            self.win,
            "Open Job",
            str(DEFAULT_JOBS_DIR),
            "KerfCut (*.kcut);;All files (*)",
        )
        if path:
            self.open_job_file(path)

    def open_job_file(self, path: str):
        from core.persistence import load_job
        try:
            job = load_job(path)
            self.win.current_file = path
            self.job_service.job = job  # fires job_changed → _refresh_all()
            self.history_service.clear()
            # _push_history() calls collect_from_ui() first, capturing the UI
            # state that was just populated by _refresh_all().
            self.win._push_history()
            self.job_service.set_dirty(False)
            self.history_service.mark_saved()
            self.win._rebuild_recent_menu()
            self.win._update_title()
            self.status_message.emit(f"Opened: {os.path.basename(path)}")
        except Exception as e:
            QMessageBox.critical(self.win, "Error", str(e))

    def import_zad(self):
        path, _ = QFileDialog.getOpenFileName(self.win, "Import Legacy Z-CAD Job", "", "Z-CAD (*.ZAD *.zad);;All files (*)")
        if path:
            from core.persistence import load_zad_file
            try:
                self.win.current_file = None
                self.job_service.job = load_zad_file(path)  # fires job_changed → _refresh_all()
                self.history_service.clear()
                # _push_history() calls collect_from_ui() first, capturing the
                # freshly-imported job state from the UI widgets.
                self.win._push_history()
                self.job_service.set_dirty(True)
                self.win._update_title(dirty=True)
                self.status_message.emit(f"Imported: {os.path.basename(path)}")
            except Exception as e:
                QMessageBox.critical(self.win, "Import Error", str(e))

    def save_job(self, save_as=False):
        path = self.win.current_file
        if save_as or not path:
            DEFAULT_JOBS_DIR.mkdir(parents=True, exist_ok=True)
            path, _ = QFileDialog.getSaveFileName(
                self.win,
                "Save Job",
                str(DEFAULT_JOBS_DIR / f"{self.job_service.job.name or 'job'}.kcut"),
                "KerfCut (*.kcut)",
            )
            if not path:
                return False
            if not path.endswith(".kcut"):
                path += ".kcut"

        from core.persistence import save_job
        try:
            # _push_history() flushes UI → job before saving, and records the
            # snapshot so that mark_saved() correctly identifies the saved state.
            self.win._push_history()
            save_job(self.job_service.job, path)
            self.win.current_file = path
            self.history_service.mark_saved()
            self.win._rebuild_recent_menu()
            self.win._update_title()
            self.status_message.emit(f"Saved: {os.path.basename(path)}")
            return True
        except Exception as e:
            QMessageBox.critical(self.win, "Save Error", str(e))
            return False

    def _confirm_discard(self) -> bool:
        if not self.job_service.is_dirty(): return True
        r = QMessageBox.question(self.win, "Unsaved Changes", "Discard unsaved changes?",
                                 QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        return r == QMessageBox.StandardButton.Yes
