"""Local health-data analysis server.

Receives health records pushed by the Stat Tracker mobile app,
stores them in SQLite, and exposes simple aggregation endpoints.

Run:
    uv pip install -r requirements.txt   # or: pip install -r requirements.txt
    uvicorn main:app --host 0.0.0.0 --port 8000
"""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

import database
from schemas import UploadBatch


@asynccontextmanager
async def lifespan(_: FastAPI):
    database.init_db()
    yield


app = FastAPI(title="Stat Tracker Server", version="1.0.0", lifespan=lifespan)

templates_dir = Path(__file__).parent / "templates"
app.mount("/static", StaticFiles(directory=str(templates_dir)), name="static")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/", response_class=HTMLResponse)
def dashboard():
    html_path = templates_dir / "dashboard.html"
    return HTMLResponse(content=html_path.read_text())


@app.post("/api/records/batch")
def upload_batch(batch: UploadBatch):
    rows = [r.model_dump() for r in batch.records]
    created = database.insert_batch(batch.source, rows)
    return {"received": len(rows), "created": created}


@app.get("/api/records")
def list_records(
    types: str | None = None,
    limit: int = 1000,
    start_date: str | None = None,
    end_date: str | None = None,
    tz: int = 0,
):
    type_list = types.split(",") if types else None
    return {
        "records": database.query_records(
            type_list, limit, start_date, end_date, tz
        )
    }


@app.get("/api/summary")
def summary(
    types: str | None = None,
    group_by: str = "type",
    start_date: str | None = None,
    end_date: str | None = None,
    tz: int = 0,
):
    type_list = types.split(",") if types else None
    return {
        "summary": database.summary(
            type_list, group_by, start_date, end_date, tz
        )
    }


@app.get("/api/summary/daily")
def summary_daily(
    types: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    tz: int = 0,
):
    type_list = types.split(",") if types else None
    return {
        "summary": database.summary(
            type_list, "substr(date_from, 1, 10)", start_date, end_date, tz
        )
    }


@app.get("/api/timeseries/{record_type}")
def timeseries(
    record_type: str,
    bucket: str = "day",
    start_date: str | None = None,
    end_date: str | None = None,
    tz: int = 0,
):
    return {
        "type": record_type,
        "bucket": bucket,
        "data": database.timeseries(
            record_type, bucket, start_date, end_date, tz
        ),
    }


@app.get("/api/date-range")
def get_date_range():
    return database.date_range()


@app.get("/api/sleep")
def sleep(
    bucket: str = "day",
    start_date: str | None = None,
    end_date: str | None = None,
    tz: int = 0,
):
    """Sleep hours per bucket, derived from record intervals."""
    return {
        "data": database.sleep_summary(bucket, start_date, end_date, tz)
    }
