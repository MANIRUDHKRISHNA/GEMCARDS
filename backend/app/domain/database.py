import json
import logging
import os
import sqlite3
from pathlib import Path
from collections.abc import Callable
from typing import Any, TypeVar

logger = logging.getLogger(__name__)
Result = TypeVar("Result")


class DatabaseError(Exception):
    """Raised when persistent demo storage cannot complete an operation."""


def _default_path() -> Path:
    configured_path = os.getenv("GEMCARDS_DATABASE_PATH")
    if configured_path:
        path = Path(configured_path).expanduser()
        return path if path.is_absolute() else Path.cwd() / path
    return Path(__file__).resolve().parents[2] / "data" / "gemcards.sqlite3"


_database_path = _default_path()
_record_entities = {
    "cards",
    "transactions",
    "fraud_alerts",
    "disputes",
    "card_applications",
    "audit_events",
    "balances",
}


def configure(path: str | Path) -> None:
    global _database_path
    _database_path = Path(path).expanduser().resolve()
    initialize()


def _connect() -> sqlite3.Connection:
    if str(_database_path) != ":memory:":
        _database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(_database_path, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA busy_timeout = 10000")
    return connection


def _run(
    operation: str,
    callback: Callable[[sqlite3.Connection], Result],
) -> Result:
    try:
        with _connect() as connection:
            return callback(connection)
    except (OSError, sqlite3.Error) as error:
        logger.exception("SQLite %s failed", operation)
        raise DatabaseError("Persistent demo storage is unavailable") from error


def initialize() -> None:
    def create_schema(connection: sqlite3.Connection) -> None:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS customers (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS domain_records (
                entity TEXT NOT NULL,
                id TEXT NOT NULL,
                customer_id TEXT,
                payload_json TEXT NOT NULL,
                PRIMARY KEY (entity, id),
                FOREIGN KEY (customer_id) REFERENCES customers(id)
            );
            CREATE TABLE IF NOT EXISTS kyc_sessions (
                id TEXT PRIMARY KEY,
                customer_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                FOREIGN KEY (customer_id) REFERENCES customers(id)
            );
            CREATE TABLE IF NOT EXISTS sequences (
                name TEXT PRIMARY KEY,
                value INTEGER NOT NULL
            );
            INSERT OR IGNORE INTO schema_migrations (version) VALUES (1);
            """
        )

    _run("schema initialization", create_schema)


def seed(state: dict[str, dict[str, dict[str, Any]]]) -> None:
    def insert_seed(connection: sqlite3.Connection) -> None:
        existing_customers = connection.execute(
            "SELECT COUNT(*) FROM customers"
        ).fetchone()[0]
        if existing_customers:
            return
        for customer_id, payload in state["customers"].items():
            connection.execute(
                "INSERT INTO customers (id, payload_json) VALUES (?, ?)",
                (customer_id, json.dumps(payload)),
            )
        for entity in _record_entities:
            for record_id, payload in state.get(entity, {}).items():
                connection.execute(
                    """
                    INSERT INTO domain_records (entity, id, customer_id, payload_json)
                    VALUES (?, ?, ?, ?)
                    """,
                    (
                        entity,
                        record_id,
                        payload.get("customer_id"),
                        json.dumps(payload),
                    ),
                )

    _run("seed", insert_seed)


def load_entities(entity: str) -> dict[str, dict[str, Any]]:
    def load(connection: sqlite3.Connection) -> dict[str, dict[str, Any]]:
        if entity == "customers":
            rows = connection.execute(
                "SELECT id, payload_json FROM customers"
            ).fetchall()
        elif entity == "kyc_sessions":
            rows = connection.execute(
                "SELECT id, payload_json FROM kyc_sessions"
            ).fetchall()
        elif entity in _record_entities:
            rows = connection.execute(
                "SELECT id, payload_json FROM domain_records WHERE entity = ?",
                (entity,),
            ).fetchall()
        else:
            raise ValueError(f"Unsupported persistent entity: {entity}")
        try:
            return {row["id"]: json.loads(row["payload_json"]) for row in rows}
        except json.JSONDecodeError as error:
            logger.exception("SQLite %s contains invalid JSON", entity)
            raise DatabaseError("Persistent demo storage is unavailable") from error

    return _run("load", load)


def save_entity(entity: str, payload: dict[str, Any]) -> None:
    record_id = payload.get("id")
    if not isinstance(record_id, str) or not record_id:
        raise ValueError("Persistent records require a non-empty id")
    payload_json = json.dumps(payload)

    def save(connection: sqlite3.Connection) -> None:
        if entity == "customers":
            connection.execute(
                """
                INSERT INTO customers (id, payload_json) VALUES (?, ?)
                ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json
                """,
                (record_id, payload_json),
            )
        elif entity == "kyc_sessions":
            connection.execute(
                """
                INSERT INTO kyc_sessions (id, customer_id, payload_json)
                VALUES (?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    customer_id = excluded.customer_id,
                    payload_json = excluded.payload_json
                """,
                (record_id, payload["customer_id"], payload_json),
            )
        elif entity in _record_entities:
            connection.execute(
                """
                INSERT INTO domain_records (entity, id, customer_id, payload_json)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(entity, id) DO UPDATE SET
                    customer_id = excluded.customer_id,
                    payload_json = excluded.payload_json
                """,
                (entity, record_id, payload.get("customer_id"), payload_json),
            )
        else:
            raise ValueError(f"Unsupported persistent entity: {entity}")

    _run("save", save)


def next_sequence(name: str) -> int:
    def increment(connection: sqlite3.Connection) -> int:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute(
            "SELECT value FROM sequences WHERE name = ?", (name,)
        ).fetchone()
        value = 1 if row is None else int(row["value"]) + 1
        connection.execute(
            """
            INSERT INTO sequences (name, value) VALUES (?, ?)
            ON CONFLICT(name) DO UPDATE SET value = excluded.value
            """,
            (name, value),
        )
        return value

    return _run("sequence update", increment)
