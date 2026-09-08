"""Local persistence for completed tutor challenges."""
from __future__ import annotations

from datetime import datetime, timezone
import os
from pathlib import Path
import sys

import pandas as pd


_COLUMNS = ("timestamp_utc", "sign", "accuracy_percent", "points_earned", "total_score", "streak")


def default_progress_path() -> Path:
    """Use project data during development and a writable user folder when frozen."""
    if getattr(sys, "frozen", False):
        base = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "SignAssistant"
        return base / "progress_stats.csv"
    return Path(__file__).resolve().parent.parent / "data" / "progress_stats.csv"


class ProgressStore:
    """Append tutor results to a simple CSV that can be opened in Excel."""

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or default_progress_path()

    def record(self, sign: str, accuracy: int, points: int, total_score: int, streak: int) -> None:
        """Append one completed challenge without replacing prior sessions."""
        self.path.parent.mkdir(parents=True, exist_ok=True)
        row = pd.DataFrame(
            [[
                datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                sign,
                max(0, min(100, int(accuracy))),
                int(points),
                int(total_score),
                int(streak),
            ]],
            columns=_COLUMNS,
        )
        row.to_csv(self.path, mode="a", index=False, header=not self.path.exists())
