import json
from PyQt6.QtCore import QObject, pyqtSignal
from core.persistence import job_to_dict, job_from_dict

class HistoryService(QObject):
    """Service to manage the Undo/Redo stack using Job snapshots."""

    stack_changed = pyqtSignal(bool, bool) # can_undo, can_redo

    def __init__(self, job_service):
        super().__init__()
        self.job_service = job_service
        self._history = []
        self._index = -1
        self._saved_index = -1
        self._lock = False

    def _snapshot(self):
        data = job_to_dict(self.job_service.job)
        data.pop("saved_at", None)
        return json.dumps(data, sort_keys=True)

    def push(self):
        if self._lock: return

        snapshot = self._snapshot()

        # If no change, don't push
        if self._index >= 0 and self._history[self._index] == snapshot:
            return

        # Truncate redo stack
        self._history = self._history[:self._index + 1]
        self._history.append(snapshot)
        self._index = len(self._history) - 1

        # Limit size
        if len(self._history) > 50:
            self._history.pop(0)
            self._index -= 1
            self._saved_index -= 1

        self._emit_status()

    def undo(self):
        if self._index > 0:
            self._index -= 1
            self._restore()

    def redo(self):
        if self._index < len(self._history) - 1:
            self._index += 1
            self._restore()

    def _restore(self):
        self._lock = True
        try:
            snapshot = self._history[self._index]
            self.job_service.job = job_from_dict(json.loads(snapshot))
            self.job_service.set_dirty(self._index != self._saved_index)
        finally:
            self._lock = False
        self._emit_status()

    def mark_saved(self):
        self._saved_index = self._index
        self.job_service.set_dirty(False)
        self._emit_status()

    def clear(self):
        self._history = []
        self._index = -1
        self._saved_index = -1
        self._emit_status()

    def _emit_status(self):
        can_undo = self._index > 0
        can_redo = self._index < len(self._history) - 1
        self.stack_changed.emit(can_undo, can_redo)
