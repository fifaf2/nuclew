from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.database import Db
from app.dependencies import CurrentUser, get_lookup_by_name
from app.models import Notification, NotificationReadStatus, PresenceStatus, User
from app.schemas import NotificationInput, PresenceInput, ProfileInput
from app.security import password_hash

router = APIRouter(prefix="/api/v1")

def serialize_user(user: User) -> dict:
    return {
        "user_id": user.user_id,
        "nickname": user.nickname,
        "email": user.email,
        "avatar_url": user.avatar_url,
        "presence_status_id": user.presence_status_id,
        "presence_status": user.presence_status.name,
        "activity_status_id": user.activity_status_id,
        "activity_status": user.activity_status.name,
    }

@router.get("/users/me", tags=["Users"], summary="Получить профиль текущего пользователя")
def get_profile(user: CurrentUser):
    return serialize_user(user)

@router.patch("/users/me", tags=["Users"], summary="Обновить профиль (никнейм, аватар, пароль)")
def update_profile(data: ProfileInput, db: Db, user: CurrentUser):
    updates = data.model_dump(exclude_unset=True)
    if not updates:
        return serialize_user(user)

    if "nickname" in updates and updates["nickname"] is not None:
        user.nickname = updates["nickname"]
    if "avatar_url" in updates:
        user.avatar_url = updates["avatar_url"]
    if updates.get("password"):
        user.password_hash = password_hash(updates["password"])

    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Псевдоним уже используется")

    return serialize_user(user)

@router.patch("/users/me/presence", tags=["Users"], summary="Изменить статус присутствия")
def update_presence(data: PresenceInput, db: Db, user: CurrentUser):
    presence = get_lookup_by_name(db, PresenceStatus, data.status)
    user.presence_status_id = presence.presence_status_id
    db.commit()
    db.refresh(user)
    return serialize_user(user)

@router.get("/users/me/notifications", tags=["Notifications"], summary="Список уведомлений пользователя")
def list_notifications(
    db: Db,
    user: CurrentUser,
    unread_only: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    stmt = select(Notification).where(Notification.recipient_user_id == user.user_id)
    if unread_only:
        stmt = stmt.join(Notification.read_status).where(
            NotificationReadStatus.name == "не прочитано"
        )
    stmt = stmt.order_by(Notification.sent_time.desc()).limit(limit).offset(offset)
    notifications = db.scalars(stmt).all()

    return [
        {
            "notification_id": n.notification_id,
            "recipient_user_id": n.recipient_user_id,
            "task_id": n.task_id,
            "text": n.text,
            "sent_time": n.sent_time,
            "status": n.read_status.name,
        }
        for n in notifications
    ]

@router.patch("/notifications/{notification_id}", tags=["Notifications"], summary="Отметить уведомление прочитанным/непрочитанным")
def mark_notification(notification_id: int, data: NotificationInput, db: Db, user: CurrentUser):
    notification = db.scalar(
        select(Notification).filter_by(
            notification_id=notification_id,
            recipient_user_id=user.user_id,
        )
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Уведомление не найдено")

    status_name = "прочитано" if data.read else "не прочитано"
    read_status = get_lookup_by_name(db, NotificationReadStatus, status_name)
    notification.read_status_id = read_status.read_status_id
    db.commit()

    return {"notification_id": notification_id, "status": status_name}
