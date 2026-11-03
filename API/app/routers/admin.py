from __future__ import annotations

import secrets

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import or_, select

from app.database import Db
from app.dependencies import CurrentUser, get_lookup_by_name, support_only, unlock_task_orm
from app.models import SystemLog, Task, TaskChange, Team, User, UserActivityStatus
from app.schemas import ActivityInput
from app.security import password_hash

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])


@router.get("/users")
def admin_users(db: Db, user: CurrentUser, q: str | None = None, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    stmt = select(User)
    if q:
        term = f"%{q}%"
        stmt = stmt.where(or_(User.nickname.like(term), User.email.like(term)))
    stmt = stmt.order_by(User.user_id.desc()).limit(limit)
    users = db.scalars(stmt).all()

    return [
        {
            "user_id": u.user_id,
            "nickname": u.nickname,
            "email": u.email,
            "avatar_url": u.avatar_url,
            "registration_time": u.registration_time,
            "activity_status": u.activity_status.name,
            "presence_status": u.presence_status.name,
        }
        for u in users
    ]


@router.patch("/users/{target_user_id}/activity")
def set_user_activity(target_user_id: int, data: ActivityInput, db: Db, user: CurrentUser):
    support_only(user)
    target = db.get(User, target_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    activity_name = "активен" if data.active else "заблокирован"
    status_obj = get_lookup_by_name(db, UserActivityStatus, activity_name)
    target.activity_status_id = status_obj.activity_status_id
    db.commit()

    return {"user_id": target_user_id, "activity_status": activity_name}


@router.post("/users/{target_user_id}/password-reset")
def reset_user_password(target_user_id: int, db: Db, user: CurrentUser):
    support_only(user)
    target = db.get(User, target_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    temporary_password = secrets.token_urlsafe(18)
    target.password_hash = password_hash(temporary_password)
    db.commit()

    return {"user_id": target_user_id, "temporary_password": temporary_password}


@router.get("/teams")
def admin_teams(db: Db, user: CurrentUser, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    teams = db.scalars(
        select(Team).order_by(Team.created_time.desc()).limit(limit)
    ).all()

    return [
        {
            "team_id": t.team_id,
            "name": t.name,
            "description": t.description,
            "creator_user_id": t.creator_user_id,
            "created_time": t.created_time,
            "owner": t.creator.nickname,
        }
        for t in teams
    ]


@router.get("/tasks/{task_id}/changes")
def admin_task_changes(task_id: int, db: Db, user: CurrentUser):
    support_only(user)
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Задача не найдена")

    changes = db.scalars(
        select(TaskChange)
        .where(TaskChange.task_id == task_id)
        .order_by(TaskChange.change_date.desc(), TaskChange.change_time.desc())
    ).all()

    return [
        {
            "change_id": c.change_id,
            "task_id": c.task_id,
            "author_user_id": c.author_user_id,
            "author_role_id": c.author_role_id,
            "change_date": c.change_date,
            "change_time": c.change_time,
            "diff_content": c.diff_content,
            "author": c.author.nickname,
            "author_role": c.author_role.name,
        }
        for c in changes
    ]


@router.post("/tasks/{task_id}/unlock")
def support_unlock_task(task_id: int, db: Db, user: CurrentUser):
    support_only(user)
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Задача не найдена")

    unlock_task_orm(db, task)
    db.commit()
    return {"task_id": task_id, "status": "свободна"}


@router.get("/system-logs")
def system_logs(db: Db, user: CurrentUser, limit: int = Query(default=100, ge=1, le=500)):
    support_only(user)
    logs = db.scalars(
        select(SystemLog).order_by(SystemLog.created_time.desc()).limit(limit)
    ).all()
    return logs
