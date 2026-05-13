"""
stats-api — Tier A analytics for the SSO-gated BentoPDF deployment.

Tails nginx's stats.log (one JSON event per protected request), stores raw
events in SQLite, and exposes aggregated views the admin dashboard renders.

Trust model:
- nginx writes the log; the values for eppn/mail/affil come from Shibboleth
  (set by shib_request_set after a verified SAML session). Clients can't spoof.
- /_internal/check-admin is intended to be hit only via nginx auth_request,
  which forwards X-Remote-User from the same shib_request_set.
- Every other endpoint trusts that nginx already enforced the admin gate;
  this service does not re-check (kept simple).
"""
from __future__ import annotations

import json
import os
import sqlite3
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse, PlainTextResponse

LOG_PATH = Path(os.environ.get("STATS_LOG_PATH", "/logs/stats.log"))
DB_PATH = Path(os.environ.get("STATS_DB_PATH", "/data/stats.sqlite"))
ADMIN_EPPNS = {
    e.strip().lower()
    for e in os.environ.get("ADMIN_EPPNS", "").split(",")
    if e.strip()
}

DB_PATH.parent.mkdir(parents=True, exist_ok=True)

# Map from URI suffix to a friendly tool name. BentoPDF serves each tool as
# its own static .html page; the URI is the most reliable signal we have at
# the nginx layer for "which tool a user opened".
# BentoPDF's internal nginx 301-redirects /foo.html → /foo, so users actually
# end up requesting the slug-only form. We accept both for forward-compat.
TOOL_PAGES = {
    "/pdf-merge-split":  "Merge / Split",
    "/pdf-converter":    "Convert",
    "/pdf-editor":       "Edit",
    "/pdf-security":     "Security",
    "/tools":            "Tool Index",
    "/about":            "About",
    "/faq":              "FAQ",
    "/contact":          "Contact",
    "/":                 "Home",
}
# Add .html aliases so old links / pre-redirect requests still group cleanly.
for k in list(TOOL_PAGES.keys()):
    if k != "/":
        TOOL_PAGES[k + ".html"] = TOOL_PAGES[k]


# --------------------------- DB helpers ---------------------------

DB_LOCK = threading.Lock()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=10, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    return conn


def _init_db() -> None:
    with _connect() as c:
        c.executescript("""
            CREATE TABLE IF NOT EXISTS events (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                ts          TEXT NOT NULL,                 -- ISO 8601, from nginx $time_iso8601
                day         TEXT NOT NULL,                 -- YYYY-MM-DD, derived for grouping
                eppn        TEXT,
                institution TEXT,                          -- domain part of eppn
                mail        TEXT,
                affil       TEXT,
                method      TEXT,
                uri         TEXT,
                status      INTEGER,
                bytes       INTEGER,
                ua          TEXT
            );
            CREATE INDEX IF NOT EXISTS ix_events_day         ON events(day);
            CREATE INDEX IF NOT EXISTS ix_events_eppn        ON events(eppn);
            CREATE INDEX IF NOT EXISTS ix_events_institution ON events(institution);
            CREATE INDEX IF NOT EXISTS ix_events_uri         ON events(uri);

            -- Bookmark for the log tailer so we don't reingest after restart.
            CREATE TABLE IF NOT EXISTS tailer_state (
                k   TEXT PRIMARY KEY,
                v   TEXT
            );
        """)


# --------------------------- log tailer ---------------------------

def _institution(eppn: str | None) -> str | None:
    if not eppn or "@" not in eppn:
        return None
    return eppn.split("@", 1)[1].lower()


def _ingest_line(c: sqlite3.Connection, line: str) -> None:
    line = line.strip()
    if not line:
        return
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        return
    # Identity fallback: some IdPs (e.g. kimlik.ulakbim.gov.tr in single-IdP
    # mode) don't release eduPersonPrincipalName. Treat `mail` as the user
    # identifier when `eppn` is empty. With Yetkim federation IdPs that DO
    # release eppn, the fallback never fires and behavior is unchanged.
    eppn = (rec.get("eppn") or rec.get("mail") or "").strip().lower() or None
    inst = _institution(eppn)
    ts = rec.get("ts") or ""
    day = ts[:10] if len(ts) >= 10 else ""
    c.execute(
        "INSERT INTO events(ts, day, eppn, institution, mail, affil, method, uri, status, bytes, ua) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (
            ts, day, eppn, inst,
            rec.get("mail") or None,
            rec.get("affil") or None,
            rec.get("method") or None,
            rec.get("uri") or None,
            int(rec.get("status") or 0),
            int(rec.get("bytes") or 0),
            (rec.get("ua") or "")[:500],
        ),
    )


def _tail_loop() -> None:
    """Cheap log tailer: reads new bytes since last bookmark, sleeps, repeats.

    Handles log truncation (rotation) by detecting size shrink and restarting
    from offset 0. Inode-tracking would be fancier but a single-tenant test
    deploy doesn't need it.
    """
    while not LOG_PATH.exists():
        time.sleep(1.0)

    with _connect() as c:
        row = c.execute("SELECT v FROM tailer_state WHERE k='offset'").fetchone()
        offset = int(row["v"]) if row else 0

    while True:
        try:
            size = LOG_PATH.stat().st_size
            if size < offset:
                # Rotated/truncated.
                offset = 0
            if size == offset:
                time.sleep(1.0)
                continue
            with LOG_PATH.open("rb") as f:
                f.seek(offset)
                chunk = f.read(size - offset)
            offset = size
            text = chunk.decode("utf-8", errors="replace")
            with DB_LOCK, _connect() as c:
                for line in text.splitlines():
                    _ingest_line(c, line)
                c.execute(
                    "INSERT INTO tailer_state(k,v) VALUES('offset', ?) "
                    "ON CONFLICT(k) DO UPDATE SET v=excluded.v",
                    (str(offset),),
                )
        except Exception as e:
            print(f"[tailer] error: {e!r}", flush=True)
            time.sleep(2.0)


# --------------------------- API ---------------------------

app = FastAPI(title="spdf-stats-api")

_init_db()
threading.Thread(target=_tail_loop, daemon=True, name="tailer").start()


@contextmanager
def db():
    with DB_LOCK:
        c = _connect()
        try:
            yield c
        finally:
            c.close()


def _date_range(days: int) -> tuple[str, str]:
    end = datetime.now(timezone.utc).date()
    start = end - timedelta(days=days - 1)
    return start.isoformat(), end.isoformat()


# ---- Admin gate: every /api/* endpoint requires X-Remote-User ∈ ADMIN_EPPNS.
#      X-Remote-User is set by nginx after Shibboleth auth — we trust it.

def require_admin(
    x_remote_user: str | None = Header(default=None),
    x_remote_mail: str | None = Header(default=None),
) -> str:
    # Same fallback as the ingest loop: prefer eppn, fall back to mail for
    # IdPs that don't release eduPersonPrincipalName.
    user = (x_remote_user or x_remote_mail or "").strip().lower()
    if not user:
        raise HTTPException(401, "Shibboleth session required (no X-Remote-User / X-Remote-Mail)")
    if not ADMIN_EPPNS or user not in ADMIN_EPPNS:
        raise HTTPException(403, f"{user} is not an admin")
    return user


# /api/healthz is intentionally unguarded so the docker healthcheck works.
# Everything else requires admin via Depends(require_admin).

@app.get("/api/healthz")
def health():
    return {"ok": True, "log_exists": LOG_PATH.exists(), "admin_count": len(ADMIN_EPPNS)}


@app.get("/api/summary")
def summary(days: int = Query(30, ge=1, le=365), _admin: str = Depends(require_admin)):
    start, end = _date_range(days)
    with db() as c:
        row = c.execute(
            "SELECT COUNT(*) AS hits, "
            "       COUNT(DISTINCT eppn) AS users, "
            "       COUNT(DISTINCT institution) AS institutions "
            "FROM events WHERE day >= ? AND eppn IS NOT NULL",
            (start,),
        ).fetchone()
        # "Sessions" ≈ distinct (day, eppn) — we don't have a real session id.
        sessions = c.execute(
            "SELECT COUNT(*) AS n FROM ("
            "  SELECT 1 FROM events WHERE day >= ? AND eppn IS NOT NULL "
            "  GROUP BY day, eppn"
            ")", (start,),
        ).fetchone()["n"]
    return {
        "range": {"from": start, "to": end, "days": days},
        "hits": row["hits"],
        "unique_users": row["users"],
        "institutions": row["institutions"],
        "user_days": sessions,
    }


@app.get("/api/by-institution")
def by_institution(days: int = Query(30, ge=1, le=365), _admin: str = Depends(require_admin)):
    start, _ = _date_range(days)
    with db() as c:
        rows = c.execute(
            "SELECT institution, "
            "       COUNT(DISTINCT eppn) AS users, "
            "       COUNT(*) AS hits "
            "FROM events "
            "WHERE day >= ? AND institution IS NOT NULL "
            "GROUP BY institution "
            "ORDER BY users DESC, hits DESC",
            (start,),
        ).fetchall()
    return [{"institution": r["institution"], "users": r["users"], "hits": r["hits"]} for r in rows]


@app.get("/api/by-tool")
def by_tool(days: int = Query(30, ge=1, le=365), _admin: str = Depends(require_admin)):
    start, _ = _date_range(days)
    with db() as c:
        rows = c.execute(
            "SELECT uri, COUNT(*) AS hits, COUNT(DISTINCT eppn) AS users "
            "FROM events "
            "WHERE day >= ? AND eppn IS NOT NULL "
            # Page navigations: either the bare slug (after BentoPDF's .html→
            # slug redirect) or the original .html URL. Skip API/static asset
            # requests so the chart focuses on user-facing tool pages.
            "  AND (uri = '/' "
            "       OR uri LIKE '%.html' "
            "       OR uri NOT LIKE '%.%' AND uri NOT LIKE '/_%') "
            "GROUP BY uri "
            "ORDER BY hits DESC "
            "LIMIT 25",
            (start,),
        ).fetchall()
    out = []
    for r in rows:
        uri = r["uri"]
        out.append({
            "uri": uri,
            "tool": TOOL_PAGES.get(uri, uri.lstrip("/").removesuffix(".html") or "/"),
            "hits": r["hits"],
            "users": r["users"],
        })
    return out


@app.get("/api/timeline")
def timeline(days: int = Query(14, ge=1, le=90), _admin: str = Depends(require_admin)):
    start, end = _date_range(days)
    with db() as c:
        rows = c.execute(
            "SELECT day, "
            "       COUNT(*) AS hits, "
            "       COUNT(DISTINCT eppn) AS users "
            "FROM events "
            "WHERE day >= ? AND eppn IS NOT NULL "
            "GROUP BY day "
            "ORDER BY day",
            (start,),
        ).fetchall()
    by_day = {r["day"]: (r["hits"], r["users"]) for r in rows}
    out = []
    cur = datetime.fromisoformat(start)
    last = datetime.fromisoformat(end)
    while cur <= last:
        d = cur.date().isoformat()
        hits, users = by_day.get(d, (0, 0))
        out.append({"day": d, "hits": hits, "users": users})
        cur += timedelta(days=1)
    return out


@app.get("/api/recent")
def recent(limit: int = Query(50, ge=1, le=500), _admin: str = Depends(require_admin)):
    with db() as c:
        rows = c.execute(
            "SELECT ts, eppn, institution, affil, method, uri, status "
            "FROM events "
            "WHERE eppn IS NOT NULL "
            "ORDER BY id DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [dict(r) for r in rows]


@app.get("/api/admins")
def admins(_admin: str = Depends(require_admin)):
    return {"admins": sorted(ADMIN_EPPNS)}
