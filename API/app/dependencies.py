from __future__ import annotations

from typing import Annotated, TypeVar

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import JWT_ALGORITHM, JWT_SECRET, SUPPORT_USER_IDS
from app.database import Base, Db
from app.models import (
    Notification,
    NotificationReadStatus,
    Task,
    TaskStatus,
    TeamMember,
    User,
)
from app.security import bearer

ModelType = TypeVar("ModelType", bound=Base)


def get_lookup_by_name(db: Session, model: type[ModelType], name: str) -> ModelType:
    obj = db.scalar(select(model).filter_by(name=name))
    if obj is None:
        raise HTTPException(status_code=500, detail=f"В БД отсутствует справочник: {name}")
    return obj


def current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Db,
) -> User:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Требуется Bearer-токен")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Недействительный токен")

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="Пользователь не найден")
    if user.activity_status.name != "активен":
        raise HTTPException(status_code=403, detail="Учётная запись заблокирована")
    return user


CurrentUser = Annotated[User, Depends(current_user)]


def membership(db: Session, team_id: int, user_id: int) -> TeamMember:
    member = db.scalar(
        select(TeamMember).filter_by(team_id=team_id, user_id=user_id)
    )
    if not member:
        raise HTTPException(status_code=403, detail="Нет доступа к команде")
    return member


def task_access(db: Session, task_id: int, user_id: int) -> tuple[Task, TeamMember]:
    task = db.scalar(
        select(Task).filter_by(task_id=task_id, is_archived=False)
    )
    if not task:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    return task, membership(db, task.team_id, user_id)


def require_role(member: TeamMember, *roles: str) -> None:
    if member.role.name not in roles:
        raise HTTPException(status_code=403, detail="Недостаточно прав")


def support_only(user: User) -> None:
    if user.user_id not in SUPPORT_USER_IDS:
        raise HTTPException(status_code=403, detail="Доступно только техподдержке")


def notify(db: Session, user_id: int, task_id: int | None, message: str) -> None:
    unread_status = get_lookup_by_name(db, NotificationReadStatus, "не прочитано")
    notification = Notification(
        recipient_user_id=user_id,
        task_id=task_id,
        text=message,
        read_status_id=unread_status.read_status_id,
    )
    db.add(notification)


def notify_team(db: Session, team_id: int, task_id: int, message: str, exclude_user_id: int) -> None:
    members = db.scalars(
        select(TeamMember).where(
            TeamMember.team_id == team_id,
            TeamMember.user_id != exclude_user_id,
        )
    ).all()
    for member in members:
        notify(db, member.user_id, task_id, message)


def unlock_task_orm(db: Session, task: Task) -> None:
    free_status = get_lookup_by_name(db, TaskStatus, "свободна")
    task.task_status_id = free_status.task_status_id
    task.assignee_user_id = None
