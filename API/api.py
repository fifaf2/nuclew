from __future__ import annotations

import difflib
import hashlib
import hmac
import os
import re
import secrets
from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Any

from fastapi import Depends, FastAPI, HTTPException, Query, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker


DATABASE_URL = os.getenv("DATABASE_URL") or URL.create(
    "mysql+pymysql",
    username=os.getenv("MYSQL_USER", "nuclew"),
    password=os.getenv("MYSQL_PASSWORD", "nuclew"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "3306")),
    database=os.getenv("MYSQL_DATABASE", "knowledge_base_db"),
    query={"charset": "utf8mb4"},
)
JWT_SECRET = os.getenv("JWT_SECRET", "change-me-before-deployment")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))
SUPPORT_USER_IDS = {
    int(value)
    for value in os.getenv("SUPPORT_USER_IDS", "").split(",")
    if value.strip().isdigit()
}

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=1800)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
bearer = HTTPBearer(auto_error=False)

app = FastAPI(title="Nuclew API", version="1.0.0")


class InputModel(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)


class RegisterInput(InputModel):
    nickname: str = Field(min_length=1, max_length=100)
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=256)


class LoginInput(InputModel):
    login: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=1, max_length=256)


class ProfileInput(InputModel):
    nickname: str | None = Field(default=None, min_length=1, max_length=100)
    avatar_url: str | None = Field(default=None, max_length=500)
    password: str | None = Field(default=None, min_length=8, max_length=256)


class PresenceInput(InputModel):
    status: str = Field(min_length=1, max_length=50)


class TeamInput(InputModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None


class InvitationInput(InputModel):
    expires_in_days: int = Field(default=7, ge=1, le=365)


class JoinInput(InputModel):
    invite_code: str = Field(min_length=1, max_length=100)


class RoleInput(InputModel):
    role: str = Field(pattern="^(участник|гость)$")


class TaskInput(InputModel):
    title: str = Field(min_length=1, max_length=500)
    content: str | None = None


class TaskUpdateInput(InputModel):
    title: str | None = Field(default=None, min_length=1, max_length=500)
    content: str | None = None


class RemarkInput(InputModel):
    fragment_identifier: str = Field(min_length=1, max_length=255)
    text: str = Field(min_length=1)
    change_id: int | None = None


class CommentInput(InputModel):
    text: str = Field(min_length=1)


class NotificationInput(InputModel):
    read: bool


class SupportRequestInput(InputModel):
    subject: str = Field(min_length=1, max_length=500)
    text: str = Field(min_length=1)


class ActivityInput(InputModel):
    active: bool


class SupportProcessInput(InputModel):
    processed: bool = True


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


Db = Annotated[Session, Depends(get_db)]


def one(db: Session, query: str, **params: Any) -> dict[str, Any] | None:
    row = db.execute(text(query), params).mappings().first()
    return dict(row) if row else None


def many(db: Session, query: str, **params: Any) -> list[dict[str, Any]]:
    return [dict(row) for row in db.execute(text(query), params).mappings().all()]


def require_one(db: Session, query: str, message: str, **params: Any) -> dict[str, Any]:
    row = one(db, query, **params)
    if row is None:
        raise HTTPException(status_code=404, detail=message)
    return row


def password_hash(password: str) -> str:
    salt = secrets.token_bytes(16)
    key = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return f"scrypt${salt.hex()}${key.hex()}"


def password_matches(password: str, stored: str) -> bool:
    if stored.startswith("scrypt$"):
        try:
            _, salt_hex, key_hex = stored.split("$", 2)
            salt, expected = bytes.fromhex(salt_hex), bytes.fromhex(key_hex)
            actual = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
            return hmac.compare_digest(actual, expected)
        except (ValueError, TypeError):
            return False
    # The supplied SQL dump contains legacy SHA-256 hashes; accept them during migration.
    legacy = hashlib.sha256(password.encode()).hexdigest()
    return hmac.compare_digest(legacy, stored)


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=JWT_EXPIRE_MINUTES)},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM,
    )


def current_user( #боже хрании ИИ
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    db: Db,
) -> dict[str, Any]:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Требуется Bearer-токен")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail="Недействительный токен")
    user = one(
        db,
        """SELECT u.user_id, u.nickname, u.email, u.avatar_url, u.presence_status_id,
                  p.name AS presence_status, u.activity_status_id, a.name AS activity_status
           FROM users u
           JOIN presence_statuses p ON p.presence_status_id = u.presence_status_id
           JOIN user_activity_statuses a ON a.activity_status_id = u.activity_status_id
           WHERE u.user_id = :user_id""",
        user_id=user_id,
    )
    if user is None:
        raise HTTPException(status_code=401, detail="Пользователь не найден")
    if user["activity_status"] != "активен":
        raise HTTPException(status_code=403, detail="Учётная запись заблокирована")
    return user


User = Annotated[dict[str, Any], Depends(current_user)]


def membership(db: Session, team_id: int, user_id: int) -> dict[str, Any]:
    member = one(
        db,
        """SELECT tm.team_member_id, tm.team_id, tm.user_id, tm.team_role_id, r.name AS role
           FROM team_members tm JOIN team_roles r ON r.team_role_id = tm.team_role_id
           WHERE tm.team_id = :team_id AND tm.user_id = :user_id""",
        team_id=team_id,
        user_id=user_id,
    )
    if not member:
        raise HTTPException(status_code=403, detail="Нет доступа к команде")
    return member


def task_access(db: Session, task_id: int, user_id: int) -> tuple[dict[str, Any], dict[str, Any]]:
    task = require_one(
        db,
        "SELECT * FROM tasks WHERE task_id = :task_id AND is_archived = 0",
        "Задача не найдена",
        task_id=task_id,
    )
    return task, membership(db, task["team_id"], user_id)


def require_role(member: dict[str, Any], *roles: str) -> None:
    if member["role"] not in roles:
        raise HTTPException(status_code=403, detail="Недостаточно прав")


def support_only(user: dict[str, Any]) -> None:
    if user["user_id"] not in SUPPORT_USER_IDS:
        raise HTTPException(status_code=403, detail="Доступно только техподдержке")


def lookup_id(db: Session, table: str, column: str, name: str) -> int:
    allowed = {
        ("presence_statuses", "presence_status_id"),
        ("user_activity_statuses", "activity_status_id"),
        ("team_roles", "team_role_id"),
        ("task_statuses", "task_status_id"),
        ("invitation_statuses", "invitation_status_id"),
        ("remark_statuses", "remark_status_id"),
        ("notification_read_statuses", "read_status_id"),
    }
    if (table, column) not in allowed:
        raise RuntimeError("Unexpected lookup")
    row = one(db, f"SELECT {column} FROM {table} WHERE name = :name", name=name)
    if row is None:
        raise HTTPException(status_code=500, detail=f"В БД отсутствует справочник: {name}")
    return row[column]


def notify(db: Session, user_id: int, task_id: int | None, message: str) -> None:
    db.execute(
        text(
            """INSERT INTO notifications
               (recipient_user_id, task_id, text, read_status_id)
               VALUES (:user_id, :task_id, :message, :unread_id)"""
        ),
        {
            "user_id": user_id,
            "task_id": task_id,
            "message": message,
            "unread_id": lookup_id(db, "notification_read_statuses", "read_status_id", "не прочитано"),
        },
    )


def notify_team(db: Session, team_id: int, task_id: int, message: str, exclude_user_id: int) -> None:
    for row in many(
        db,
        "SELECT user_id FROM team_members WHERE team_id = :team_id AND user_id != :user_id",
        team_id=team_id,
        user_id=exclude_user_id,
    ):
        notify(db, row["user_id"], task_id, message)


@app.get("/health")
def health(db: Db):
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@app.post("/api/v1/auth/register", status_code=status.HTTP_201_CREATED)
def register(data: RegisterInput, db: Db):
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", data.email):
        raise HTTPException(status_code=422, detail="Некорректный адрес электронной почты")
    try:
        db.execute(
            text(
                """INSERT INTO users
                   (nickname, email, password_hash, presence_status_id, activity_status_id)
                   VALUES (:nickname, :email, :password_hash, :presence_id, :activity_id)"""
            ),
            {
                "nickname": data.nickname,
                "email": data.email.lower(),
                "password_hash": password_hash(data.password),
                "presence_id": lookup_id(db, "presence_statuses", "presence_status_id", "на месте"),
                "activity_id": lookup_id(db, "user_activity_statuses", "activity_status_id", "активен"),
            },
        )
        db.commit()
        user_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email или псевдоним уже используются")
    return {"access_token": create_access_token(user_id), "token_type": "bearer"}


@app.post("/api/v1/auth/login")
def login(data: LoginInput, db: Db):
    user = one(
        db,
        "SELECT user_id, password_hash, activity_status_id FROM users WHERE email = :login OR nickname = :login",
        login=data.login,
    )
    if user is None or not password_matches(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")
    active_id = lookup_id(db, "user_activity_statuses", "activity_status_id", "активен")
    if user["activity_status_id"] != active_id:
        raise HTTPException(status_code=403, detail="Учётная запись заблокирована")
    if user["password_hash"].startswith("scrypt$") is False:
        db.execute(
            text("UPDATE users SET password_hash = :password_hash WHERE user_id = :user_id"),
            {"password_hash": password_hash(data.password), "user_id": user["user_id"]},
        )
        db.commit()
    return {"access_token": create_access_token(user["user_id"]), "token_type": "bearer"}


@app.get("/api/v1/users/me")
def get_profile(db: Db, user: User):
    return require_one(
        db,
        """SELECT u.user_id, u.nickname, u.email, u.avatar_url, u.presence_status_id,
                  p.name AS presence_status, u.activity_status_id, a.name AS activity_status
           FROM users u JOIN presence_statuses p ON p.presence_status_id = u.presence_status_id
           JOIN user_activity_statuses a ON a.activity_status_id = u.activity_status_id
           WHERE u.user_id = :user_id""",
        "Пользователь не найден",
        user_id=user["user_id"],
    )


@app.patch("/api/v1/users/me")
def update_profile(data: ProfileInput, db: Db, user: User):
    updates = data.model_dump(exclude_unset=True, exclude_none=False)
    if not updates:
        return user
    assignments: list[str] = []
    params: dict[str, Any] = {"user_id": user["user_id"]}
    if "nickname" in updates:
        assignments.append("nickname = :nickname")
        params["nickname"] = updates["nickname"]
    if "avatar_url" in updates:
        assignments.append("avatar_url = :avatar_url")
        params["avatar_url"] = updates["avatar_url"]
    if updates.get("password"):
        assignments.append("password_hash = :password_hash")
        params["password_hash"] = password_hash(updates["password"])
    if assignments:
        try:
            db.execute(text(f"UPDATE users SET {', '.join(assignments)} WHERE user_id = :user_id"), params)
            db.commit()
        except IntegrityError:
            db.rollback()
            raise HTTPException(status_code=409, detail="Псевдоним уже используется")
    return get_profile(db, user)


@app.patch("/api/v1/users/me/presence")
def update_presence(data: PresenceInput, db: Db, user: User):
    presence_id = lookup_id(db, "presence_statuses", "presence_status_id", data.status)
    db.execute(
        text("UPDATE users SET presence_status_id = :presence_id WHERE user_id = :user_id"),
        {"presence_id": presence_id, "user_id": user["user_id"]},
    )
    db.commit()
    return get_profile(db, user)


@app.get("/api/v1/teams")
def list_teams(db: Db, user: User):
    return many(
        db,
        """SELECT t.team_id, t.name, t.description, t.created_time, r.name AS role
           FROM teams t JOIN team_members tm ON tm.team_id = t.team_id
           JOIN team_roles r ON r.team_role_id = tm.team_role_id
           WHERE tm.user_id = :user_id ORDER BY t.team_id""",
        user_id=user["user_id"],
    )


@app.post("/api/v1/teams", status_code=status.HTTP_201_CREATED)
def create_team(data: TeamInput, db: Db, user: User):
    db.execute(
        text("INSERT INTO teams (name, description, creator_user_id) VALUES (:name, :description, :user_id)"),
        {"name": data.name, "description": data.description, "user_id": user["user_id"]},
    )
    team_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.execute(
        text("INSERT INTO team_members (team_id, user_id, team_role_id) VALUES (:team_id, :user_id, :role_id)"),
        {
            "team_id": team_id,
            "user_id": user["user_id"],
            "role_id": lookup_id(db, "team_roles", "team_role_id", "владелец команды"),
        },
    )
    db.commit()
    return {"team_id": team_id, "name": data.name, "description": data.description}


@app.get("/api/v1/teams/{team_id}")
def get_team(team_id: int, db: Db, user: User):
    membership(db, team_id, user["user_id"])
    return require_one(db, "SELECT * FROM teams WHERE team_id = :team_id", "Команда не найдена", team_id=team_id)


@app.patch("/api/v1/teams/{team_id}")
def update_team(team_id: int, data: TeamInput, db: Db, user: User):
    member = membership(db, team_id, user["user_id"])
    require_role(member, "владелец команды")
    db.execute(
        text("UPDATE teams SET name = :name, description = :description WHERE team_id = :team_id"),
        {"name": data.name, "description": data.description, "team_id": team_id},
    )
    db.commit()
    return get_team(team_id, db, user)


@app.get("/api/v1/teams/{team_id}/members")
def list_members(team_id: int, db: Db, user: User):
    membership(db, team_id, user["user_id"])
    return many(
        db,
        """SELECT u.user_id, u.nickname, u.email, u.avatar_url, p.name AS presence_status,
                  r.name AS role, tm.joined_time
           FROM team_members tm JOIN users u ON u.user_id = tm.user_id
           JOIN presence_statuses p ON p.presence_status_id = u.presence_status_id
           JOIN team_roles r ON r.team_role_id = tm.team_role_id
           WHERE tm.team_id = :team_id ORDER BY tm.joined_time""",
        team_id=team_id,
    )


@app.post("/api/v1/teams/{team_id}/invitations", status_code=status.HTTP_201_CREATED)
def create_invitation(team_id: int, data: InvitationInput, db: Db, user: User):
    member = membership(db, team_id, user["user_id"])
    require_role(member, "владелец команды")
    code = secrets.token_urlsafe(24)
    expires = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=data.expires_in_days)
    db.execute(
        text(
            """INSERT INTO invitations
               (invite_code, team_id, creator_user_id, expires_time, invitation_status_id)
               VALUES (:code, :team_id, :user_id, :expires, :status_id)"""
        ),
        {
            "code": code,
            "team_id": team_id,
            "user_id": user["user_id"],
            "expires": expires,
            "status_id": lookup_id(db, "invitation_statuses", "invitation_status_id", "активен"),
        },
    )
    invitation_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.commit()
    return {"invitation_id": invitation_id, "invite_code": code, "expires_time": expires}


@app.delete("/api/v1/invitations/{invitation_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_invitation(invitation_id: int, db: Db, user: User):
    invitation = require_one(
        db, "SELECT * FROM invitations WHERE invitation_id = :id", "Приглашение не найдено", id=invitation_id
    )
    member = membership(db, invitation["team_id"], user["user_id"])
    require_role(member, "владелец команды")
    revoked_id = lookup_id(db, "invitation_statuses", "invitation_status_id", "отозван")
    db.execute(
        text("UPDATE invitations SET invitation_status_id = :status_id WHERE invitation_id = :id"),
        {"status_id": revoked_id, "id": invitation_id},
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.post("/api/v1/invitations/join")
def join_team(data: JoinInput, db: Db, user: User):
    invitation = one(
        db,
        """SELECT * FROM invitations WHERE invite_code = :code
           AND invitation_status_id = :active_id AND expires_time > UTC_TIMESTAMP()
           FOR UPDATE""",
        code=data.invite_code,
        active_id=lookup_id(db, "invitation_statuses", "invitation_status_id", "активен"),
    )
    if invitation is None:
        db.rollback()
        raise HTTPException(status_code=400, detail="Код приглашения недействителен или истёк")
    if one(
        db,
        "SELECT team_member_id FROM team_members WHERE team_id = :team_id AND user_id = :user_id",
        team_id=invitation["team_id"],
        user_id=user["user_id"],
    ):
        raise HTTPException(status_code=409, detail="Вы уже состоите в этой команде")
    db.execute(
        text("INSERT INTO team_members (team_id, user_id, team_role_id) VALUES (:team_id, :user_id, :role_id)"),
        {
            "team_id": invitation["team_id"],
            "user_id": user["user_id"],
            "role_id": lookup_id(db, "team_roles", "team_role_id", "участник"),
        },
    )
    db.execute(
        text(
            "UPDATE invitations SET invitation_status_id = :used_id WHERE invitation_id = :invitation_id"
        ),
        {
            "used_id": lookup_id(db, "invitation_statuses", "invitation_status_id", "использован"),
            "invitation_id": invitation["invitation_id"],
        },
    )
    db.commit()
    return {"team_id": invitation["team_id"], "role": "участник"}


@app.patch("/api/v1/teams/{team_id}/members/{member_user_id}")
def update_member_role(team_id: int, member_user_id: int, data: RoleInput, db: Db, user: User):
    owner = membership(db, team_id, user["user_id"])
    require_role(owner, "владелец команды")
    target = membership(db, team_id, member_user_id)
    if target["role"] == "владелец команды":
        raise HTTPException(status_code=400, detail="Нельзя изменить роль владельца")
    role_id = lookup_id(db, "team_roles", "team_role_id", data.role)
    db.execute(
        text(
            "UPDATE team_members SET team_role_id = :role_id WHERE team_id = :team_id AND user_id = :user_id"
        ),
        {"role_id": role_id, "team_id": team_id, "user_id": member_user_id},
    )
    db.commit()
    return {"team_id": team_id, "user_id": member_user_id, "role": data.role}


@app.delete("/api/v1/teams/{team_id}/members/{member_user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_member(team_id: int, member_user_id: int, db: Db, user: User):
    owner = membership(db, team_id, user["user_id"])
    require_role(owner, "владелец команды")
    target = membership(db, team_id, member_user_id)
    if target["role"] == "владелец команды":
        raise HTTPException(status_code=400, detail="Нельзя исключить владельца команды")
    db.execute(
        text("DELETE FROM team_members WHERE team_id = :team_id AND user_id = :user_id"),
        {"team_id": team_id, "user_id": member_user_id},
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/api/v1/teams/{team_id}/tasks")
def list_tasks(
    team_id: int,
    db: Db,
    user: User,
    task_status: str | None = Query(default=None, alias="status"),
    include_archived: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    membership(db, team_id, user["user_id"])
    if task_status is not None:
        lookup_id(db, "task_statuses", "task_status_id", task_status)
    return many(
        db,
        """SELECT t.task_id, t.team_id, t.title, t.task_status_id, s.name AS status,
                  t.assignee_user_id, u.nickname AS assignee, t.created_time, t.last_modified_at,
                  t.is_archived
           FROM tasks t JOIN task_statuses s ON s.task_status_id = t.task_status_id
           LEFT JOIN users u ON u.user_id = t.assignee_user_id
           WHERE t.team_id = :team_id AND (:include_archived = 1 OR t.is_archived = 0)
             AND (:status IS NULL OR s.name = :status)
           ORDER BY t.last_modified_at DESC, t.task_id DESC LIMIT :limit OFFSET :offset""",
        team_id=team_id,
        include_archived=include_archived,
        status=task_status,
        limit=limit,
        offset=offset,
    )


@app.post("/api/v1/teams/{team_id}/tasks", status_code=status.HTTP_201_CREATED)
def create_task(team_id: int, data: TaskInput, db: Db, user: User):
    member = membership(db, team_id, user["user_id"])
    require_role(member, "владелец команды")
    db.execute(
        text(
            """INSERT INTO tasks (team_id, title, content, task_status_id)
               VALUES (:team_id, :title, :content, :status_id)"""
        ),
        {
            "team_id": team_id,
            "title": data.title,
            "content": data.content or "",
            "status_id": lookup_id(db, "task_statuses", "task_status_id", "свободна"),
        },
    )
    task_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.commit()
    return get_task(task_id, db, user)


@app.get("/api/v1/tasks/{task_id}")
def get_task(task_id: int, db: Db, user: User):
    task, _ = task_access(db, task_id, user["user_id"])
    task["status"] = one(
        db, "SELECT name FROM task_statuses WHERE task_status_id = :id", id=task["task_status_id"]
    )["name"]
    return task


@app.post("/api/v1/tasks/{task_id}/claim")
def claim_task(task_id: int, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды", "участник")
    free_id = lookup_id(db, "task_statuses", "task_status_id", "свободна")
    rework_id = lookup_id(db, "task_statuses", "task_status_id", "на доработке")
    working_id = lookup_id(db, "task_statuses", "task_status_id", "в работе")
    result = db.execute(
        text(
            """UPDATE tasks SET task_status_id = :working, assignee_user_id = :user_id
               WHERE task_id = :task_id AND is_archived = 0
                 AND (task_status_id = :free OR
                      (task_status_id = :rework AND
                       (assignee_user_id IS NULL OR assignee_user_id = :user_id)))"""
        ),
        {
            "working": working_id,
            "user_id": user["user_id"],
            "task_id": task_id,
            "free": free_id,
            "rework": rework_id,
        },
    )
    if result.rowcount != 1:
        db.rollback()
        raise HTTPException(status_code=409, detail="Задача уже занята или не свободна")
    db.commit()
    return get_task(task_id, db, user)


@app.patch("/api/v1/tasks/{task_id}")
def update_task(task_id: int, data: TaskUpdateInput, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды", "участник")
    if task["assignee_user_id"] != user["user_id"]:
        raise HTTPException(status_code=409, detail="Сначала возьмите задачу в работу")
    if not data.model_fields_set:
        return get_task(task_id, db, user)
    old_content = task["content"] or ""
    new_content = data.content if "content" in data.model_fields_set else old_content
    title = data.title if data.title is not None else task["title"]
    diff = "".join(
        difflib.unified_diff(
            old_content.splitlines(keepends=True),
            (new_content or "").splitlines(keepends=True),
            fromfile="before.md",
            tofile="after.md",
        )
    )
    db.execute(
        text(
            """UPDATE tasks SET title = :title, content = :content, last_modified_at = UTC_TIMESTAMP()
               WHERE task_id = :task_id"""
        ),
        {"title": title, "content": new_content, "task_id": task_id},
    )
    if diff or title != task["title"]:
        db.execute(
            text(
                """INSERT INTO task_changes
                   (task_id, author_user_id, author_role_id, change_date, change_time, diff_content)
                   VALUES (:task_id, :user_id, :role_id, :change_date, :change_time, :diff)"""
            ),
            {
                "task_id": task_id,
                "user_id": user["user_id"],
                "role_id": member["team_role_id"],
                "change_date": date.today(),
                "change_time": datetime.now().time().replace(microsecond=0),
                "diff": diff or f"Заголовок: {task['title']} -> {title}",
            },
        )
    db.commit()
    return get_task(task_id, db, user)


@app.post("/api/v1/tasks/{task_id}/complete")
def complete_task(task_id: int, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды", "участник")
    if task["assignee_user_id"] != user["user_id"]:
        raise HTTPException(status_code=409, detail="Эту задачу редактирует другой участник")
    status_id = lookup_id(db, "task_statuses", "task_status_id", "завершена")
    db.execute(
        text(
            """UPDATE tasks SET task_status_id = :status_id, assignee_user_id = NULL,
               last_modified_at = UTC_TIMESTAMP() WHERE task_id = :task_id"""
        ),
        {"status_id": status_id, "task_id": task_id},
    )
    notify_team(db, task["team_id"], task_id, f"Задача «{task['title']}» завершена", user["user_id"])
    db.commit()
    return get_task(task_id, db, user)


def unlock_task(db: Session, task_id: int, task: dict[str, Any]):
    db.execute(
        text(
            """UPDATE tasks SET task_status_id = :status_id, assignee_user_id = NULL
               WHERE task_id = :task_id"""
        ),
        {
            "status_id": lookup_id(db, "task_statuses", "task_status_id", "свободна"),
            "task_id": task_id,
        },
    )


@app.post("/api/v1/tasks/{task_id}/unlock")
def owner_unlock_task(task_id: int, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды")
    unlock_task(db, task_id, task)
    db.commit()
    return get_task(task_id, db, user)


@app.post("/api/v1/tasks/{task_id}/archive")
def archive_task(task_id: int, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды")
    db.execute(text("UPDATE tasks SET is_archived = 1 WHERE task_id = :id"), {"id": task_id})
    db.commit()
    return {"task_id": task_id, "is_archived": True}


@app.get("/api/v1/tasks/{task_id}/changes")
def list_changes(task_id: int, db: Db, user: User):
    task, _ = task_access(db, task_id, user["user_id"])
    return many(
        db,
        """SELECT c.change_id, c.task_id, c.author_user_id, u.nickname AS author,
                  r.name AS author_role, c.change_date, c.change_time, c.diff_content
           FROM task_changes c JOIN users u ON u.user_id = c.author_user_id
           JOIN team_roles r ON r.team_role_id = c.author_role_id
           WHERE c.task_id = :task_id ORDER BY c.change_date DESC, c.change_time DESC""",
        task_id=task["task_id"],
    )


@app.get("/api/v1/tasks/{task_id}/comments")
def list_comments(task_id: int, db: Db, user: User):
    task_access(db, task_id, user["user_id"])
    return many(
        db,
        """SELECT c.comment_id, c.task_id, c.author_user_id, u.nickname AS author,
                  c.text, c.created_time
           FROM comments c JOIN users u ON u.user_id = c.author_user_id
           WHERE c.task_id = :task_id ORDER BY c.created_time""",
        task_id=task_id,
    )


@app.post("/api/v1/tasks/{task_id}/comments", status_code=status.HTTP_201_CREATED)
def add_comment(task_id: int, data: CommentInput, db: Db, user: User):
    _, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды", "участник")
    db.execute(
        text("INSERT INTO comments (task_id, author_user_id, text) VALUES (:task_id, :user_id, :text)"),
        {"task_id": task_id, "user_id": user["user_id"], "text": data.text},
    )
    comment_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.commit()
    return {"comment_id": comment_id, "task_id": task_id, "text": data.text}


@app.get("/api/v1/tasks/{task_id}/remarks")
def list_remarks(task_id: int, db: Db, user: User):
    task_access(db, task_id, user["user_id"])
    return many(
        db,
        """SELECT r.remark_id, r.task_id, r.change_id, r.author_user_id,
                  u.nickname AS author, r.fragment_identifier, r.text, r.sent_time,
                  s.name AS status
           FROM remarks r JOIN users u ON u.user_id = r.author_user_id
           JOIN remark_statuses s ON s.remark_status_id = r.remark_status_id
           WHERE r.task_id = :task_id ORDER BY r.sent_time DESC""",
        task_id=task_id,
    )


@app.post("/api/v1/tasks/{task_id}/remarks", status_code=status.HTTP_201_CREATED)
def add_remark(task_id: int, data: RemarkInput, db: Db, user: User):
    task, member = task_access(db, task_id, user["user_id"])
    require_role(member, "владелец команды", "участник")
    if data.change_id is not None and one(
        db,
        "SELECT change_id FROM task_changes WHERE change_id = :change_id AND task_id = :task_id",
        change_id=data.change_id,
        task_id=task_id,
    ) is None:
        raise HTTPException(status_code=404, detail="Версия задачи не найдена")
    assignee_user_id = task["assignee_user_id"]
    if assignee_user_id is None and data.change_id is not None:
        change = one(
            db,
            "SELECT author_user_id FROM task_changes WHERE change_id = :change_id",
            change_id=data.change_id,
        )
        assignee_user_id = change["author_user_id"] if change else None
    db.execute(
        text(
            """INSERT INTO remarks
               (task_id, change_id, author_user_id, fragment_identifier, text, remark_status_id)
               VALUES (:task_id, :change_id, :user_id, :fragment, :remark, :status_id)"""
        ),
        {
            "task_id": task_id,
            "change_id": data.change_id,
            "user_id": user["user_id"],
            "fragment": data.fragment_identifier,
            "remark": data.text,
            "status_id": lookup_id(db, "remark_statuses", "remark_status_id", "открыто"),
        },
    )
    remark_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.execute(
        text(
            """UPDATE tasks SET task_status_id = :status_id, assignee_user_id = :assignee_id
               WHERE task_id = :task_id"""
        ),
        {
            "status_id": lookup_id(db, "task_statuses", "task_status_id", "на доработке"),
            "assignee_id": assignee_user_id,
            "task_id": task_id,
        },
    )
    if assignee_user_id and assignee_user_id != user["user_id"]:
        notify(db, assignee_user_id, task_id, f"Новое замечание к задаче «{task['title']}»")
    db.commit()
    return {"remark_id": remark_id, "task_id": task_id, "status": "открыто"}


@app.patch("/api/v1/remarks/{remark_id}")
def resolve_remark(remark_id: int, db: Db, user: User):
    remark = require_one(db, "SELECT * FROM remarks WHERE remark_id = :id", "Замечание не найдено", id=remark_id)
    task, member = task_access(db, remark["task_id"], user["user_id"])
    require_role(member, "владелец команды", "участник")
    if user["user_id"] != remark["author_user_id"] and task["assignee_user_id"] != user["user_id"]:
        require_role(member, "владелец команды")
    db.execute(
        text("UPDATE remarks SET remark_status_id = :status_id WHERE remark_id = :id"),
        {
            "status_id": lookup_id(db, "remark_statuses", "remark_status_id", "устранено"),
            "id": remark_id,
        },
    )
    db.commit()
    return {"remark_id": remark_id, "status": "устранено"}


@app.get("/api/v1/users/me/notifications")
def list_notifications(
    db: Db,
    user: User,
    unread_only: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    return many(
        db,
        """SELECT n.notification_id, n.recipient_user_id, n.task_id, n.text, n.sent_time,
                  s.name AS status
           FROM notifications n JOIN notification_read_statuses s ON s.read_status_id = n.read_status_id
           WHERE n.recipient_user_id = :user_id AND (:unread = 0 OR s.name = 'не прочитано')
           ORDER BY n.sent_time DESC LIMIT :limit OFFSET :offset""",
        user_id=user["user_id"],
        unread=unread_only,
        limit=limit,
        offset=offset,
    )


@app.patch("/api/v1/notifications/{notification_id}")
def mark_notification(notification_id: int, data: NotificationInput, db: Db, user: User):
    notification = require_one(
        db,
        "SELECT * FROM notifications WHERE notification_id = :id AND recipient_user_id = :user_id",
        "Уведомление не найдено",
        id=notification_id,
        user_id=user["user_id"],
    )
    read_status = "прочитано" if data.read else "не прочитано"
    db.execute(
        text("UPDATE notifications SET read_status_id = :status_id WHERE notification_id = :id"),
        {
            "status_id": lookup_id(db, "notification_read_statuses", "read_status_id", read_status),
            "id": notification["notification_id"],
        },
    )
    db.commit()
    return {"notification_id": notification_id, "status": read_status}


@app.post("/api/v1/support/requests", status_code=status.HTTP_201_CREATED)
def create_support_request(data: SupportRequestInput, db: Db, user: User):
    db.execute(
        text("INSERT INTO support_requests (user_id, subject, text) VALUES (:user_id, :subject, :text)"),
        {"user_id": user["user_id"], "subject": data.subject, "text": data.text},
    )
    request_id = db.execute(text("SELECT LAST_INSERT_ID()")).scalar_one()
    db.commit()
    return {"request_id": request_id, "subject": data.subject}


@app.get("/api/v1/support/requests")
def list_support_requests(db: Db, user: User, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    return many(
        db,
        """SELECT sr.*, u.nickname, u.email
           FROM support_requests sr JOIN users u ON u.user_id = sr.user_id
           ORDER BY sr.created_time DESC LIMIT :limit""",
        limit=limit,
    )


@app.patch("/api/v1/support/requests/{request_id}")
def process_support_request(request_id: int, data: SupportProcessInput, db: Db, user: User):
    support_only(user)
    require_one(
        db, "SELECT request_id FROM support_requests WHERE request_id = :id", "Обращение не найдено", id=request_id
    )
    db.execute(
        text(
            """UPDATE support_requests SET processed_time = :processed,
               processed_by_user_id = :processor WHERE request_id = :id"""
        ),
        {
            "processed": datetime.now() if data.processed else None,
            "processor": user["user_id"] if data.processed else None,
            "id": request_id,
        },
    )
    db.commit()
    return {"request_id": request_id, "processed": data.processed}


@app.get("/api/v1/teams/{team_id}/reports/task-statuses")
def task_status_report(team_id: int, db: Db, user: User):
    membership(db, team_id, user["user_id"])
    return many(
        db,
        """SELECT s.name AS status, COUNT(t.task_id) AS task_count
           FROM task_statuses s LEFT JOIN tasks t
             ON t.task_status_id = s.task_status_id AND t.team_id = :team_id AND t.is_archived = 0
           GROUP BY s.task_status_id, s.name ORDER BY s.task_status_id""",
        team_id=team_id,
    )


@app.get("/api/v1/teams/{team_id}/reports/activity")
def activity_report(team_id: int, db: Db, user: User):
    member = membership(db, team_id, user["user_id"])
    require_role(member, "владелец команды")
    return many(
        db,
        """SELECT u.user_id, u.nickname, COUNT(DISTINCT c.change_id) AS changes_count,
                  COUNT(DISTINCT cm.comment_id) AS comments_count
           FROM team_members tm JOIN users u ON u.user_id = tm.user_id
           LEFT JOIN tasks t ON t.team_id = tm.team_id
           LEFT JOIN task_changes c ON c.task_id = t.task_id AND c.author_user_id = u.user_id
           LEFT JOIN comments cm ON cm.task_id = t.task_id AND cm.author_user_id = u.user_id
           WHERE tm.team_id = :team_id GROUP BY u.user_id, u.nickname ORDER BY u.nickname""",
        team_id=team_id,
    )


@app.get("/api/v1/tasks/{task_id}/export")
def export_task(task_id: int, db: Db, user: User):
    task, _ = task_access(db, task_id, user["user_id"])
    filename = re.sub(r"[^a-zA-Z0-9_-]+", "-", task["title"]).strip("-") or f"task-{task_id}"
    return Response(
        content=f"# {task['title']}\n\n{task['content'] or ''}",
        media_type="text/markdown",
        headers={"Content-Disposition": f'attachment; filename="{filename}.md"'},
    )


@app.get("/api/v1/admin/users")
def admin_users(db: Db, user: User, q: str | None = None, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    term = f"%{q}%" if q else "%"
    return many(
        db,
        """SELECT u.user_id, u.nickname, u.email, u.avatar_url, u.registration_time,
                  a.name AS activity_status, p.name AS presence_status
           FROM users u JOIN user_activity_statuses a ON a.activity_status_id = u.activity_status_id
           JOIN presence_statuses p ON p.presence_status_id = u.presence_status_id
           WHERE u.nickname LIKE :term OR u.email LIKE :term ORDER BY u.user_id DESC LIMIT :limit""",
        term=term,
        limit=limit,
    )


@app.patch("/api/v1/admin/users/{target_user_id}/activity")
def set_user_activity(target_user_id: int, data: ActivityInput, db: Db, user: User):
    support_only(user)
    require_one(db, "SELECT user_id FROM users WHERE user_id = :id", "Пользователь не найден", id=target_user_id)
    activity = "активен" if data.active else "заблокирован"
    db.execute(
        text("UPDATE users SET activity_status_id = :status_id WHERE user_id = :user_id"),
        {
            "status_id": lookup_id(db, "user_activity_statuses", "activity_status_id", activity),
            "user_id": target_user_id,
        },
    )
    db.commit()
    return {"user_id": target_user_id, "activity_status": activity}


@app.post("/api/v1/admin/users/{target_user_id}/password-reset")
def reset_user_password(target_user_id: int, db: Db, user: User):
    support_only(user)
    require_one(db, "SELECT user_id FROM users WHERE user_id = :id", "Пользователь не найден", id=target_user_id)
    temporary_password = secrets.token_urlsafe(18)
    db.execute(
        text("UPDATE users SET password_hash = :password_hash WHERE user_id = :user_id"),
        {"password_hash": password_hash(temporary_password), "user_id": target_user_id},
    )
    db.commit()
    return {"user_id": target_user_id, "temporary_password": temporary_password}


@app.get("/api/v1/admin/teams")
def admin_teams(db: Db, user: User, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    return many(
        db,
        """SELECT t.*, u.nickname AS owner
           FROM teams t JOIN users u ON u.user_id = t.creator_user_id
           ORDER BY t.created_time DESC LIMIT :limit""",
        limit=limit,
    )


@app.get("/api/v1/admin/tasks/{task_id}/changes")
def admin_task_changes(task_id: int, db: Db, user: User):
    support_only(user)
    require_one(db, "SELECT task_id FROM tasks WHERE task_id = :id", "Задача не найдена", id=task_id)
    return many(
        db,
        """SELECT c.*, u.nickname AS author, r.name AS author_role
           FROM task_changes c JOIN users u ON u.user_id = c.author_user_id
           JOIN team_roles r ON r.team_role_id = c.author_role_id
           WHERE c.task_id = :task_id ORDER BY c.change_date DESC, c.change_time DESC""",
        task_id=task_id,
    )


@app.post("/api/v1/admin/tasks/{task_id}/unlock")
def support_unlock_task(task_id: int, db: Db, user: User):
    support_only(user)
    task = require_one(db, "SELECT * FROM tasks WHERE task_id = :id", "Задача не найдена", id=task_id)
    unlock_task(db, task_id, task)
    db.commit()
    return {"task_id": task_id, "status": "свободна"}


@app.get("/api/v1/admin/system-logs")
def system_logs(db: Db, user: User, limit: int = Query(default=100, ge=1, le=500)):
    support_only(user)
    return many(
        db,
        "SELECT * FROM system_logs ORDER BY created_time DESC LIMIT :limit",
        limit=limit,
    )
