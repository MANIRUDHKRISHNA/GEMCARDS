from pathlib import Path

import pytest

from app.api.routes import kyc
from app.domain import store


@pytest.fixture(autouse=True)
def isolated_demo_database(tmp_path: Path) -> None:
    database_path = tmp_path / "gemcards-test.sqlite3"
    store.configure_database(database_path)
    kyc.reload_sessions()
