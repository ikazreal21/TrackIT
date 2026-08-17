"""Local health-data analysis server.

Receives health records pushed by the Stat Tracker mobile app,
stores them in SQLite, and exposes simple aggregation endpoints.

Run:
    uv pip install -r requirements.txt   # or: pip install -r requirements.txt
    uvicorn main:app --host 0.0.0.0 --port 8000
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import database
from schemas import SummaryParams, UploadBatch


@asynccontextmanager
async def lifespan(_: FastAPI):
    database.init_db()
    yield


app = FastAPI(title="Stat Tracker Server", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/records/batch")
def upload_batch(batch: UploadBatch):
    rows = [r.model_dump() for r in batch.records]
    created = database.insert_batch(batch.source, rows)
    return {"received": len(rows), "created": created}


@app.get("/api/records")
def list_records(types: str | None = None, limit: int = 1000):
    type_list = types.split(",") if types else None
    return {"records": database.query_records(type_list, limit)}


@app.get("/api/summary")
def summary(types: str | None = None, group_by: str = "type"):
    type_list = types.split(",") if types else None
    return {"summary": database.summary(type_list, group_by)}


@app.get("/api/summary/daily")
def summary_daily(types: str | None = None):
    """Aggregate by calendar day (from date_from) for trend analysis."""
    type_list = types.split(",") if types else None
    return {"summary": database.summary(type_list, "substr(date_from, 1, 10)")}