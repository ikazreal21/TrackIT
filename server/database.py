"""SQLite-backed persistence for health records.

Kept dependency-free (stdlib sqlite3) so the local server
is trivial to run and query for analysis.
"""

import os
import sqlite3
from contextlib import contextmanager

DATABASE_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "stats.db",
)

SCHEMA = """
CREATE TABLE IF NOT EXISTS records (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    source      TEXT NOT NULL DEFAULT 'unknown',
    type        TEXT NOT NULL,
    value       REAL NOT NULL,
    unit        TEXT NOT NULL DEFAULT '',
    date_from   TEXT NOT NULL,
    date_to     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_records_type ON records(type);
CREATE INDEX IF NOT EXISTS idx_records_date_from ON records(date_from);
"""


@contextmanager
def get_conn():
    conn = sqlite3.connect(DATABASE_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with get_conn() as conn:
        conn.executescript(SCHEMA)


def insert_batch(source: str, rows: list[dict]) -> int:
    """Insert multiple records, skipping exact duplicates. Returns count created."""
    created = 0
    with get_conn() as conn:
        cur = conn.cursor()
        for r in rows:
            exists = cur.execute(
                """
                SELECT 1 FROM records
                WHERE type = ? AND value = ? AND date_from = ? AND date_to = ?
                """,
                (r["type"], r["value"], r["date_from"], r["date_to"]),
            ).fetchone()
            if exists:
                continue
            cur.execute(
                """
                INSERT INTO records (source, type, value, unit, date_from, date_to)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    source,
                    r["type"],
                    r["value"],
                    r["unit"],
                    r["date_from"],
                    r["date_to"],
                ),
            )
            created += 1
    return created


def query_records(types: list[str] | None = None, limit: int = 1000) -> list[dict]:
    sql = "SELECT id, source, type, value, unit, date_from, date_to FROM records"
    params: list = []
    if types:
        placeholders = ",".join("?" for _ in types)
        sql += f" WHERE type IN ({placeholders})"
        params.extend(types)
    sql += " ORDER BY date_from DESC LIMIT ?"
    params.append(limit)

    with get_conn() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [
        {
            "id": r[0],
            "source": r[1],
            "type": r[2],
            "value": r[3],
            "unit": r[4],
            "date_from": r[5],
            "date_to": r[6],
        }
        for r in rows
    ]


def summary(
    types: list[str] | None = None,
    group_by: str = "type",
) -> list[dict]:
    """Basic analysis: aggregate records (count, sum, avg, min, max)."""
    type_filter = ""
    params: list = []
    if types:
        placeholders = ",".join("?" for _ in types)
        type_filter = f"WHERE type IN ({placeholders})"
        params.extend(types)

    sql = f"""
        SELECT {group_by}, COUNT(*), SUM(value), AVG(value), MIN(value), MAX(value)
        FROM records
        {type_filter}
        GROUP BY {group_by}
        ORDER BY {group_by}
    """
    with get_conn() as conn:
        rows = conn.execute(sql, params).fetchall()

    return [
        {
            "key": r[0],
            "count": r[1],
            "sum": r[2],
            "avg": r[3],
            "min": r[4],
            "max": r[5],
        }
        for r in rows
    ]