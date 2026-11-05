from __future__ import annotations

import re

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError

from app.database import Db
from app.dependencies import get_lookup_by_name
from app.models import PresenceStatus, User, UserActivityStatus
from app.schemas import LoginInput, RegisterInput
from app.security import create_access_token, password_hash, password_matches

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])

@router.post("/register", status_code=status.HTTP_201_CREATED, summary="Регистрация нового пользователя")
def register(data: RegisterInput, db: Db):
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", data.email):
        raise HTTPException(status_code=422, detail="Некорректный адрес электронной почты")

    presence = get_lookup_by_name(db, PresenceStatus, "на месте")
    activity = get_lookup_by_name(db, UserActivityStatus, "активен")

    user = User(
        nickname=data.nickname,
        email=data.email.lower(),
        password_hash=password_hash(data.password),
        presence_status_id=presence.presence_status_id,
        activity_status_id=activity.activity_status_id,
    )
    try:
        db.add(user)
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email или псевдоним уже используются")

    return {"access_token": create_access_token(user.user_id), "token_type": "bearer"}

@router.post("/login", summary="Авторизация и получение JWT-токена")
def login(data: LoginInput, db: Db):
    user = db.scalar(
        select(User).where(
            or_(User.email == data.login, User.nickname == data.login)
        )
    )
    if user is None or not password_matches(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")

    if user.activity_status.name != "активен":
        raise HTTPException(status_code=403, detail="Учётная запись заблокирована")

    if not user.password_hash.startswith("scrypt$"):
        user.password_hash = password_hash(data.password)
        db.commit()

    return {"access_token": create_access_token(user.user_id), "token_type": "bearer"}
