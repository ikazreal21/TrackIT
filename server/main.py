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
from schemas import SummaryParams, UploadBatch


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


@app.get("/bare", response_class=HTMLResponse)
def bare_dashboard():
    total_records = database.query_records(limit=1_000_000)
    type_summary = database.summary(group_by="type")
    daily_summary = database.summary(group_by="substr(date_from, 1, 10)")
    recent = database.query_records(limit=20)

    rows = ""
    for r in recent:
        rows += f"""
        <tr>
            <td>{r['date_from'][:19]}</td>
            <td>{r['type']}</td>
            <td>{r['value']:.2f}</td>
            <td>{r['unit']}</td>
        </tr>
        """

    summary_cards = ""
    for s in type_summary:
        summary_cards += f"""
        <div class="card">
            <h3>{s['key']}</h3>
            <p>Count: {s['count']}</p>
            <p>Total: {s['sum']:.2f}</p>
            <p>Avg: {s['avg']:.2f}</p>
        </div>
        """

    daily_rows = ""
    for d in sorted(daily_summary, key=lambda x: x["key"], reverse=True)[:14]:
        daily_rows += f"""
        <tr>
            <td>{d['key']}</td>
            <td>{d['count']}</td>
            <td>{d['sum']:.2f}</td>
        </tr>
        """

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TrackIT Server - Simple</title>
    <style>
        :root {{
        color-scheme: light dark;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1000px;
            margin: 0 auto;
            padding: 2rem;
            background: #0f172a;
            color: #e2e8f0;
        }}
        h1 {{
            color: #38bdf8;
            margin-bottom: 0.25rem;
        }}
        .subtitle {{
            color: #94a3b8;
            margin-bottom: 2rem;
        }}
        .status {{
            display: inline-block;
            background: #059669;
            color: white;
            padding: 0.4rem 0.8rem;
            border-radius: 999px;
            font-size: 0.9rem;
            margin-bottom: 2rem;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }}
        .card {{
            background: #1e293b;
            border-radius: 12px;
            padding: 1rem;
            border: 1px solid #334155;
        }}
        .card h3 {{
            margin-top: 0;
            color: #38bdf8;
            text-transform: uppercase;
            font-size: 0.9rem;
            letter-spacing: 0.05em;
        }}
        .card p {{
            margin: 0.4rem 0;
            color: #cbd5e1;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            background: #1e293b;
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid #334155;
        }}
        th, td {{
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid #334155;
        }}
        th {{
            background: #334155;
            color: #38bdf8;
        }}
        .section {{
            margin-bottom: 2rem;
        }}
        .section h2 {{
            color: #38bdf8;
            margin-bottom: 0.75rem;
        }}
    </style>
</head>
<body>
    <h1>TrackIT Server</h1>
    <p class="subtitle">Simple Dashboard View</p>
    <span class="status">Running</span>

    <div class="section">
        <h2>Overview</h2>
        <p>Total records stored: <strong>{len(total_records)}</strong></p>
    </div>

    <div class="section">
        <h2>Summary by Type</h2>
        <div class="grid">
            {summary_cards}
        </div>
    </div>

    <div class="section">
        <h2>Daily Totals (last 14 days)</h2>
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Count</th>
                    <th>Sum</th>
                </tr>
            </thead>
            <tbody>
                {daily_rows if daily_rows else '<tr><td colspan="3">No data yet</td></tr>'}
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Recent Records</h2>
        <table>
            <thead>
                <tr>
                    <th>Time</th>
                    <th>Type</th>
                    <th>Value</th>
                    <th>Unit</th>
                </tr>
            </thead>
            <tbody>
                {rows if rows else '<tr><td colspan="4">No data yet</td></tr>'}
            </tbody>
        </table>
    </div>

    <footer style="margin-top: 3rem; color: #64748b; font-size: 0.85rem;">
        <a href="/" style="color:#38bdf8">Full Dashboard</a> | <a href="/docs" style="color:#38bdf8">/docs</a> | <a href="/health" style="color:#38bdf8">/health</a>
    </footer>
</body>
</html>"""
    return html


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