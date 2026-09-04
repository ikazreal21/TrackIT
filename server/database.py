"""SQLite-backed persistence for health records.

Kept dependency-free (stdlib sqlite3) so the local server
is trivial to run and query for analysis.
"""

import os
import sqlite3
from contextlib import contextmanager

_data_dir = os.environ.get("DATA_DIR", os.path.dirname(os.path.abspath(__file__)))
os.makedirs(_data_dir, exist_ok=True)
DATABASE_PATH = os.path.join(_data_dir, "stats.db")

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


def _build_type_filter(types: list[str] | None) -> tuple[str, list]:
    if not types:
        return "", []
    placeholders = ",".join("?" for _ in types)
    return f"WHERE type IN ({placeholders})", list(types)


def _tz_minutes(tz_offset: int | None) -> int:
    """Sanitise a viewer timezone offset (minutes east of UTC)."""
    try:
        mins = int(tz_offset or 0)
    except (TypeError, ValueError):
        return 0
    return max(-840, min(840, mins))


def _shifted(col: str, tz_offset: int | None) -> str:
    """Column expression shifted into the viewer's timezone.

    tz_offset=0 (default) leaves data in UTC — behaviour unchanged.
    """
    mins = _tz_minutes(tz_offset)
    if not mins:
        return col
    sign = "+" if mins >= 0 else "-"
    return f"datetime({col}, '{sign}{abs(mins)} minutes')"


def _day_col(tz_offset: int | None) -> str:
    """Local calendar-day expression used for range filtering."""
    return f"substr({_shifted('date_from', tz_offset)}, 1, 10)"


def _build_date_filter(
    start_date: str | None,
    end_date: str | None,
    existing_where: str = "",
    tz_offset: int | None = 0,
) -> tuple[str, list]:
    clauses = []
    params: list = []
    if existing_where:
        clauses.append(existing_where)
    if _tz_minutes(tz_offset):
        day = _day_col(tz_offset)
        if start_date:
            clauses.append(f"{day} >= ?")
            params.append(start_date)
        if end_date:
            clauses.append(f"{day} <= ?")
            params.append(end_date)
    else:
        if start_date:
            clauses.append("date_from >= ?")
            params.append(start_date)
        if end_date:
            clauses.append("date_from <= ?")
            params.append(end_date + "T23:59:59")
    if not clauses:
        return "", []
    return "WHERE " + " AND ".join(clauses), params


def query_records(
    types: list[str] | None = None,
    limit: int = 1000,
    start_date: str | None = None,
    end_date: str | None = None,
    tz_offset: int | None = 0,
) -> list[dict]:
    type_where, type_params = _build_type_filter(types)
    date_where, date_params = _build_date_filter(
        start_date, end_date, type_where, tz_offset
    )

    sql = f"SELECT id, source, type, value, unit, date_from, date_to FROM records {date_where} ORDER BY date_from DESC LIMIT ?"
    params = type_params + date_params + [limit]

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
    start_date: str | None = None,
    end_date: str | None = None,
    tz_offset: int | None = 0,
) -> list[dict]:
    type_where, type_params = _build_type_filter(types)
    date_where, date_params = _build_date_filter(
        start_date, end_date, type_where, tz_offset
    )

    sql = f"""
        SELECT {group_by}, COUNT(*), SUM(value), AVG(value), MIN(value), MAX(value)
        FROM records
        {date_where}
        GROUP BY {group_by}
        ORDER BY {group_by}
    """
    params = type_params + date_params

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


def _bucket_exprs(tz_offset: int | None) -> dict[str, str]:
    shifted = _shifted("date_from", tz_offset)
    return {
        "hour": f"substr({shifted}, 1, 13)",
        "day": f"substr({shifted}, 1, 10)",
        "week": f"strftime('%Y-W%W', {shifted})",
        "month": f"substr({shifted}, 1, 7)",
    }


def _range_clauses(
    start_date: str | None,
    end_date: str | None,
    tz_offset: int | None,
) -> tuple[list[str], list]:
    """Date-range clauses over the viewer's local calendar day."""
    clauses: list[str] = []
    params: list = []
    if _tz_minutes(tz_offset):
        day = _day_col(tz_offset)
        if start_date:
            clauses.append(f"{day} >= ?")
            params.append(start_date)
        if end_date:
            clauses.append(f"{day} <= ?")
            params.append(end_date)
    else:
        if start_date:
            clauses.append("date_from >= ?")
            params.append(start_date)
        if end_date:
            clauses.append("date_from <= ?")
            params.append(end_date + "T23:59:59")
    return clauses, params


def timeseries(
    record_type: str,
    bucket: str = "day",
    start_date: str | None = None,
    end_date: str | None = None,
    tz_offset: int | None = 0,
) -> list[dict]:
    group_expr = _bucket_exprs(tz_offset).get(
        bucket, _bucket_exprs(tz_offset)["day"]
    )

    clauses = ["type = ?"]
    params: list = [record_type]

    extra, extra_params = _range_clauses(start_date, end_date, tz_offset)
    clauses.extend(extra)
    params.extend(extra_params)

    date_where = "WHERE " + " AND ".join(clauses)

    sql = f"""
        SELECT {group_expr}, COUNT(*), SUM(value), AVG(value), MIN(value), MAX(value)
        FROM records
        {date_where}
        GROUP BY {group_expr}
        ORDER BY {group_expr}
    """

    with get_conn() as conn:
        rows = conn.execute(sql, params).fetchall()

    return [
        {
            "bucket": r[0],
            "count": r[1],
            "sum": r[2],
            "avg": r[3],
            "min": r[4],
            "max": r[5],
        }
        for r in rows
    ]


def date_range() -> dict:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT MIN(substr(date_from, 1, 10)), MAX(substr(date_from, 1, 10)), COUNT(*) FROM records"
        ).fetchone()
    return {
        "earliest": row[0],
        "latest": row[1],
        "total_records": row[2],
    }


def _duration_seconds(col_from: str = "date_from", col_to: str = "date_to") -> str:
    """SQL expression: seconds between two ISO-8601 timestamps.

    Normalises the 'T' separator and trailing 'Z' so phone-style UTC
    strings parse, and falls back to 0 when unparseable.
    """
    norm = lambda c: f"REPLACE(REPLACE({c}, 'T', ' '), 'Z', '')"  # noqa: E731
    return (
        f"COALESCE(strftime('%s', {norm(col_to)})"
        f" - strftime('%s', {norm(col_from)}), 0)"
    )


def sleep_summary(
    bucket: str = "day",
    start_date: str | None = None,
    end_date: str | None = None,
    tz_offset: int | None = 0,
) -> list[dict]:
    """Sleep hours per bucket, computed from record intervals.

    Phone sleep values arrive in minutes while older data may use seconds,
    so durations are derived from date_to - date_from instead of value.
    Prefers SLEEP_SESSION; falls back to SLEEP_ASLEEP per bucket.
    """
    exprs = _bucket_exprs(tz_offset)
    group_expr = exprs.get(bucket, exprs["day"])
    dur = _duration_seconds()

    per_bucket: dict[str, dict[str, float]] = {}
    for sleep_type in ("SLEEP_SESSION", "SLEEP_ASLEEP"):
        clauses = ["type = ?"]
        params: list = [sleep_type]
        extra, extra_params = _range_clauses(start_date, end_date, tz_offset)
        clauses.extend(extra)
        params.extend(extra_params)
        sql = f"""
            SELECT {group_expr}, SUM({dur})
            FROM records
            WHERE {' AND '.join(clauses)}
            GROUP BY {group_expr}
            ORDER BY {group_expr}
        """
        with get_conn() as conn:
            rows = conn.execute(sql, params).fetchall()
        for b, s in rows:
            per_bucket.setdefault(b, {})[sleep_type] = s or 0

    result = []
    for b in sorted(per_bucket):
        d = per_bucket[b]
        seconds = d.get("SLEEP_SESSION") or d.get("SLEEP_ASLEEP") or 0
        result.append({"bucket": b, "hours": round(seconds / 3600, 1)})
    return result
