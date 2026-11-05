from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.database import Db
from app.routers import admin, auth, support, tasks, teams, users

app = FastAPI(title="Nuclew API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["health"])
def health(db: Db):
    db.scalar(select(1))
    return {"status": "ok", "database": "connected"}

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(teams.router)
app.include_router(tasks.router)
app.include_router(support.router)
app.include_router(admin.router)
