from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import and_, func, select

from app.database import Db
from app.dependencies import CurrentUser, get_lookup_by_name, membership, require_role
from app.models import (
    Comment,
    Invitation,
    InvitationStatus,
    Task,
    TaskChange,
    TaskStatus,
    Team,
    TeamMember,
    TeamRole,
    User,
)
from app.schemas import InvitationInput, JoinInput, RoleInput, TeamInput

router = APIRouter(prefix="/api/v1", tags=["teams"])

@router.get("/teams")
def list_teams(db: Db, user: CurrentUser):
    memberships = db.scalars(
        select(TeamMember)
        .where(TeamMember.user_id == user.user_id)
        .order_by(TeamMember.team_id)
    ).all()

    return [
        {
            "team_id": tm.team.team_id,
            "name": tm.team.name,
            "description": tm.team.description,
            "created_time": tm.team.created_time,
            "role": tm.role.name,
        }
        for tm in memberships
    ]

@router.post("/teams", status_code=status.HTTP_201_CREATED)
def create_team(data: TeamInput, db: Db, user: CurrentUser):
    owner_role = get_lookup_by_name(db, TeamRole, "владелец команды")

    team = Team(
        name=data.name,
        description=data.description,
        creator_user_id=user.user_id,
    )
    db.add(team)
    db.flush()

    member = TeamMember(
        team_id=team.team_id,
        user_id=user.user_id,
        team_role_id=owner_role.team_role_id,
    )
    db.add(member)
    db.commit()
    db.refresh(team)

    return {"team_id": team.team_id, "name": team.name, "description": team.description}

@router.get("/teams/{team_id}")
def get_team(team_id: int, db: Db, user: CurrentUser):
    membership(db, team_id, user.user_id)
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(status_code=404, detail="Команда не найдена")
    return {
        "team_id": team.team_id,
        "name": team.name,
        "description": team.description,
        "creator_user_id": team.creator_user_id,
        "created_time": team.created_time,
    }

@router.patch("/teams/{team_id}")
def update_team(team_id: int, data: TeamInput, db: Db, user: CurrentUser):
    member = membership(db, team_id, user.user_id)
    require_role(member, "владелец команды")

    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(status_code=404, detail="Команда не найдена")

    team.name = data.name
    team.description = data.description
    db.commit()
    db.refresh(team)
    return get_team(team_id, db, user)

@router.get("/teams/{team_id}/members")
def list_members(team_id: int, db: Db, user: CurrentUser):
    membership(db, team_id, user.user_id)
    members = db.scalars(
        select(TeamMember)
        .where(TeamMember.team_id == team_id)
        .order_by(TeamMember.joined_time)
    ).all()

    return [
        {
            "user_id": tm.user.user_id,
            "nickname": tm.user.nickname,
            "email": tm.user.email,
            "avatar_url": tm.user.avatar_url,
            "presence_status": tm.user.presence_status.name,
            "role": tm.role.name,
            "joined_time": tm.joined_time,
        }
        for tm in members
    ]

@router.post("/teams/{team_id}/invitations", status_code=status.HTTP_201_CREATED)
def create_invitation(team_id: int, data: InvitationInput, db: Db, user: CurrentUser):
    member = membership(db, team_id, user.user_id)
    require_role(member, "владелец команды")

    active_status = get_lookup_by_name(db, InvitationStatus, "активен")
    code = secrets.token_urlsafe(24)
    expires = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=data.expires_in_days)

    invitation = Invitation(
        invite_code=code,
        team_id=team_id,
        creator_user_id=user.user_id,
        expires_time=expires,
        invitation_status_id=active_status.invitation_status_id,
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    return {
        "invitation_id": invitation.invitation_id,
        "invite_code": invitation.invite_code,
        "expires_time": invitation.expires_time,
    }

@router.delete("/invitations/{invitation_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_invitation(invitation_id: int, db: Db, user: CurrentUser):
    invitation = db.get(Invitation, invitation_id)
    if not invitation:
        raise HTTPException(status_code=404, detail="Приглашение не найдено")

    member = membership(db, invitation.team_id, user.user_id)
    require_role(member, "владелец команды")

    revoked_status = get_lookup_by_name(db, InvitationStatus, "отозван")
    invitation.invitation_status_id = revoked_status.invitation_status_id
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.post("/invitations/join")
def join_team(data: JoinInput, db: Db, user: CurrentUser):
    active_status = get_lookup_by_name(db, InvitationStatus, "активен")
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)

    invitation = db.scalar(
        select(Invitation)
        .where(
            Invitation.invite_code == data.invite_code,
            Invitation.invitation_status_id == active_status.invitation_status_id,
            Invitation.expires_time > now_utc,
        )
        .with_for_update()
    )
    if invitation is None:
        db.rollback()
        raise HTTPException(status_code=400, detail="Код приглашения недействителен или истёк")

    existing = db.scalar(
        select(TeamMember).filter_by(team_id=invitation.team_id, user_id=user.user_id)
    )
    if existing:
        raise HTTPException(status_code=409, detail="Вы уже состоите в этой команде")

    participant_role = get_lookup_by_name(db, TeamRole, "участник")
    used_status = get_lookup_by_name(db, InvitationStatus, "использован")

    new_member = TeamMember(
        team_id=invitation.team_id,
        user_id=user.user_id,
        team_role_id=participant_role.team_role_id,
    )
    invitation.invitation_status_id = used_status.invitation_status_id

    db.add(new_member)
    db.commit()

    return {"team_id": invitation.team_id, "role": "участник"}

@router.patch("/teams/{team_id}/members/{member_user_id}")
def update_member_role(team_id: int, member_user_id: int, data: RoleInput, db: Db, user: CurrentUser):
    owner = membership(db, team_id, user.user_id)
    require_role(owner, "владелец команды")

    target = membership(db, team_id, member_user_id)
    if target.role.name == "владелец команды":
        raise HTTPException(status_code=400, detail="Нельзя изменить роль владельца")

    new_role = get_lookup_by_name(db, TeamRole, data.role)
    target.team_role_id = new_role.team_role_id
    db.commit()

    return {"team_id": team_id, "user_id": member_user_id, "role": data.role}

@router.delete("/teams/{team_id}/members/{member_user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_member(team_id: int, member_user_id: int, db: Db, user: CurrentUser):
    owner = membership(db, team_id, user.user_id)
    require_role(owner, "владелец команды")

    target = membership(db, team_id, member_user_id)
    if target.role.name == "владелец команды":
        raise HTTPException(status_code=400, detail="Нельзя исключить владельца команды")

    db.delete(target)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.get("/teams/{team_id}/reports/task-statuses")
def task_status_report(team_id: int, db: Db, user: CurrentUser):
    membership(db, team_id, user.user_id)
    rows = db.execute(
        select(
            TaskStatus.name.label("status"),
            func.count(Task.task_id).label("task_count"),
        )
        .outerjoin(
            Task,
            and_(
                Task.task_status_id == TaskStatus.task_status_id,
                Task.team_id == team_id,
                Task.is_archived.is_(False),
            ),
        )
        .group_by(TaskStatus.task_status_id, TaskStatus.name)
        .order_by(TaskStatus.task_status_id)
    ).mappings().all()

    return [dict(r) for r in rows]

@router.get("/teams/{team_id}/reports/activity")
def activity_report(team_id: int, db: Db, user: CurrentUser):
    member = membership(db, team_id, user.user_id)
    require_role(member, "владелец команды")

    rows = db.execute(
        select(
            User.user_id,
            User.nickname,
            func.count(func.distinct(TaskChange.change_id)).label("changes_count"),
            func.count(func.distinct(Comment.comment_id)).label("comments_count"),
        )
        .select_from(TeamMember)
        .join(User, User.user_id == TeamMember.user_id)
        .outerjoin(Task, Task.team_id == TeamMember.team_id)
        .outerjoin(
            TaskChange,
            and_(TaskChange.task_id == Task.task_id, TaskChange.author_user_id == User.user_id),
        )
        .outerjoin(
            Comment,
            and_(Comment.task_id == Task.task_id, Comment.author_user_id == User.user_id),
        )
        .where(TeamMember.team_id == team_id)
        .group_by(User.user_id, User.nickname)
        .order_by(User.nickname)
    ).mappings().all()

    return [dict(r) for r in rows]
