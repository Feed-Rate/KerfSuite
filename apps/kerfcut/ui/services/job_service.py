from PyQt6.QtCore import QObject, pyqtSignal
from core.models import Job, ensure_unique_job_ids

class JobService(QObject):
    """Owner of the active Job data. Central point for data synchronization."""

    job_changed = pyqtSignal()
    results_changed = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._job = Job()
        self._dirty = False

    @property
    def job(self) -> Job:
        return self._job

    @job.setter
    def job(self, new_job: Job):
        self._job = new_job
        ensure_unique_job_ids(self._job)
        self.job_changed.emit()

    def set_dirty(self, dirty: bool = True):
        self._dirty = dirty

    def is_dirty(self) -> bool:
        return self._dirty

    def clear_results(self):
        self._job.layouts = []
        self._job.unplaced = []
        self.results_changed.emit()
