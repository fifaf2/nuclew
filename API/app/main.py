from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.database import Db
from app.routers import admin, auth, support, tasks, teams, users

tags_metadata = [
    {"name": "Auth", "description": "Регистрация и авторизация пользователей (JWT)"},
    {"name": "Users", "description": "Профиль текущего пользователя и статус присутствия"},
    {"name": "Notifications", "description": "Внутрисистемные уведомления пользователя"},
    {"name": "Teams", "description": "Управление командами и участниками"},
    {"name": "Invitations", "description": "Инвайт-коды и вступление в команду"},
    {"name": "Reports", "description": "Аналитические отчёты по задачам и активности команды"},
    {"name": "Tasks", "description": "Работа с задачами, версионность (diff) и экспорт в Markdown"},
    {"name": "Comments & Remarks", "description": "Комментарии к задачам и замечания на доработку"},
    {"name": "Support", "description": "Обращения пользователей в техническую поддержку"},
    {"name": "Admin", "description": "Панель администратора и техподдержки"},
    {"name": "Health", "description": "Проверка состояния сервиса и подключения к БД"},
]

app = FastAPI(
    title="Nuclew API",
    version="1.0.0",
    description="API системы управления базой знаний и командными задачами",
    openapi_tags=tags_metadata,
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["Health"], summary="Проверка работоспособности API и БД")
def health(db: Db):
    db.scalar(select(1))
    return {"status": "ok", "database": "connected"}

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(teams.router)
app.include_router(tasks.router)
app.include_router(support.router)
app.include_router(admin.router)
