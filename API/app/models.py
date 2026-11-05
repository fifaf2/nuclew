from __future__ import annotations

from datetime import date, datetime, time

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, Text, Time, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

# Справочники:

class PresenceStatus(Base):
    __tablename__ = "presence_statuses"

    presence_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class UserActivityStatus(Base):
    __tablename__ = "user_activity_statuses"

    activity_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class TeamRole(Base):
    __tablename__ = "team_roles"

    team_role_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class TaskStatus(Base):
    __tablename__ = "task_statuses"

    task_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class InvitationStatus(Base):
    __tablename__ = "invitation_statuses"

    invitation_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class RemarkStatus(Base):
    __tablename__ = "remark_statuses"

    remark_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

class NotificationReadStatus(Base):
    __tablename__ = "notification_read_statuses"

    read_status_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

# Основные таблицы:

class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nickname: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    presence_status_id: Mapped[int] = mapped_column(ForeignKey("presence_statuses.presence_status_id"), nullable=False)
    activity_status_id: Mapped[int] = mapped_column(ForeignKey("user_activity_statuses.activity_status_id"), nullable=False)
    registration_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    presence_status: Mapped[PresenceStatus] = relationship("PresenceStatus", lazy="joined")
    activity_status: Mapped[UserActivityStatus] = relationship("UserActivityStatus", lazy="joined")

class Team(Base):
    __tablename__ = "teams"

    team_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    creator_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    creator: Mapped[User] = relationship("User")
    members: Mapped[list[TeamMember]] = relationship("TeamMember", back_populates="team", cascade="all, delete-orphan")

class TeamMember(Base):
    __tablename__ = "team_members"

    team_member_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    team_id: Mapped[int] = mapped_column(ForeignKey("teams.team_id"), nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    team_role_id: Mapped[int] = mapped_column(ForeignKey("team_roles.team_role_id"), nullable=False)
    joined_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    team: Mapped[Team] = relationship("Team", back_populates="members")
    user: Mapped[User] = relationship("User", lazy="joined")
    role: Mapped[TeamRole] = relationship("TeamRole", lazy="joined")

class Invitation(Base):
    __tablename__ = "invitations"

    invitation_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    invite_code: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    team_id: Mapped[int] = mapped_column(ForeignKey("teams.team_id"), nullable=False)
    creator_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    expires_time: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    invitation_status_id: Mapped[int] = mapped_column(ForeignKey("invitation_statuses.invitation_status_id"), nullable=False)

    status: Mapped[InvitationStatus] = relationship("InvitationStatus", lazy="joined")

class Task(Base):
    __tablename__ = "tasks"

    task_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    team_id: Mapped[int] = mapped_column(ForeignKey("teams.team_id"), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    task_status_id: Mapped[int] = mapped_column(ForeignKey("task_statuses.task_status_id"), nullable=False)
    assignee_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    last_modified_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    status: Mapped[TaskStatus] = relationship("TaskStatus", lazy="joined")
    assignee: Mapped[User | None] = relationship("User", lazy="joined")

class TaskChange(Base):
    __tablename__ = "task_changes"

    change_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    task_id: Mapped[int] = mapped_column(ForeignKey("tasks.task_id"), nullable=False)
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    author_role_id: Mapped[int] = mapped_column(ForeignKey("team_roles.team_role_id"), nullable=False)
    change_date: Mapped[date] = mapped_column(Date, nullable=False)
    change_time: Mapped[time] = mapped_column(Time, nullable=False)
    diff_content: Mapped[str] = mapped_column(Text, nullable=False)

    author: Mapped[User] = relationship("User", lazy="joined")
    author_role: Mapped[TeamRole] = relationship("TeamRole", lazy="joined")

class Comment(Base):
    __tablename__ = "comments"

    comment_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    task_id: Mapped[int] = mapped_column(ForeignKey("tasks.task_id"), nullable=False)
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    author: Mapped[User] = relationship("User", lazy="joined")

class Remark(Base):
    __tablename__ = "remarks"

    remark_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    task_id: Mapped[int] = mapped_column(ForeignKey("tasks.task_id"), nullable=False)
    change_id: Mapped[int | None] = mapped_column(ForeignKey("task_changes.change_id"), nullable=True)
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    fragment_identifier: Mapped[str] = mapped_column(String(255), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    sent_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    remark_status_id: Mapped[int] = mapped_column(ForeignKey("remark_statuses.remark_status_id"), nullable=False)

    author: Mapped[User] = relationship("User", lazy="joined")
    status: Mapped[RemarkStatus] = relationship("RemarkStatus", lazy="joined")

class Notification(Base):
    __tablename__ = "notifications"

    notification_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    recipient_user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    task_id: Mapped[int | None] = mapped_column(ForeignKey("tasks.task_id"), nullable=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    sent_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    read_status_id: Mapped[int] = mapped_column(ForeignKey("notification_read_statuses.read_status_id"), nullable=False)

    read_status: Mapped[NotificationReadStatus] = relationship("NotificationReadStatus", lazy="joined")

class SupportRequest(Base):
    __tablename__ = "support_requests"

    request_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"), nullable=False)
    subject: Mapped[str] = mapped_column(String(500), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    processed_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    processed_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)

    user: Mapped[User] = relationship("User", foreign_keys=[user_id], lazy="joined")

class SystemLog(Base):
    __tablename__ = "system_logs"

    log_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.user_id"), nullable=True)
    action: Mapped[str | None] = mapped_column(String(255), nullable=True)
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
