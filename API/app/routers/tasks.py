from __future__ import annotations

import difflib
import re
from datetime import date, datetime, timezone

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.database import Db
from app.dependencies import (
    CurrentUser,
    get_lookup_by_name,
    membership,
    notify,
    notify_team,
    require_role,
    task_access,
    unlock_task_orm,
)
from app.models import (
    Comment,
    Remark,
    RemarkStatus,
    Task,
    TaskChange,
    TaskStatus,
)
from app.schemas import CommentInput, RemarkInput, TaskInput, TaskUpdateInput

router = APIRouter(prefix="/api/v1", tags=["tasks"])

def serialize_task(task: Task) -> dict:
    return {
        "task_id": task.task_id,
        "team_id": task.team_id,
        "title": task.title,
        "content": task.content,
        "task_status_id": task.task_status_id,
        "status": task.status.name,
        "assignee_user_id": task.assignee_user_id,
        "created_time": task.created_time,
        "last_modified_at": task.last_modified_at,
        "is_archived": task.is_archived,
    }

@router.get("/teams/{team_id}/tasks")
def list_tasks(
    team_id: int,
    db: Db,
    user: CurrentUser,
    task_status: str | None = Query(default=None, alias="status"),
    include_archived: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    membership(db, team_id, user.user_id)
    stmt = select(Task).where(Task.team_id == team_id)

    if not include_archived:
        stmt = stmt.where(Task.is_archived.is_(False))
    if task_status is not None:
        status_obj = get_lookup_by_name(db, TaskStatus, task_status)
        stmt = stmt.where(Task.task_status_id == status_obj.task_status_id)

    stmt = stmt.order_by(Task.last_modified_at.desc(), Task.task_id.desc()).limit(limit).offset(offset)
    tasks = db.scalars(stmt).all()

    return [
        {
            "task_id": t.task_id,
            "team_id": t.team_id,
            "title": t.title,
            "task_status_id": t.task_status_id,
            "status": t.status.name,
            "assignee_user_id": t.assignee_user_id,
            "assignee": t.assignee.nickname if t.assignee else None,
            "created_time": t.created_time,
            "last_modified_at": t.last_modified_at,
            "is_archived": t.is_archived,
        }
        for t in tasks
    ]

@router.post("/teams/{team_id}/tasks", status_code=status.HTTP_201_CREATED)
def create_task(team_id: int, data: TaskInput, db: Db, user: CurrentUser):
    member = membership(db, team_id, user.user_id)
    require_role(member, "владелец команды")

    free_status = get_lookup_by_name(db, TaskStatus, "свободна")
    task = Task(
        team_id=team_id,
        title=data.title,
        content=data.content or "",
        task_status_id=free_status.task_status_id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return serialize_task(task)

@router.get("/tasks/{task_id}")
def get_task(task_id: int, db: Db, user: CurrentUser):
    task, _ = task_access(db, task_id, user.user_id)
    return serialize_task(task)

@router.post("/tasks/{task_id}/claim")
def claim_task(task_id: int, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    current_status = task.status.name
    can_claim = current_status == "свободна" or (
        current_status == "на доработке"
        and task.assignee_user_id in (None, user.user_id)
    )
    if not can_claim:
        raise HTTPException(status_code=409, detail="Задача уже занята или не свободна")

    working_status = get_lookup_by_name(db, TaskStatus, "в работе")
    task.task_status_id = working_status.task_status_id
    task.assignee_user_id = user.user_id
    db.commit()
    db.refresh(task)
    return serialize_task(task)

@router.patch("/tasks/{task_id}")
def update_task(task_id: int, data: TaskUpdateInput, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    if task.assignee_user_id != user.user_id:
        raise HTTPException(status_code=409, detail="Сначала возьмите задачу в работу")
    if not data.model_fields_set:
        return serialize_task(task)

    old_title = task.title
    old_content = task.content or ""
    new_content = data.content if "content" in data.model_fields_set else old_content
    new_title = data.title if data.title is not None else old_title

    diff = "".join(
        difflib.unified_diff(
            old_content.splitlines(keepends=True),
            (new_content or "").splitlines(keepends=True),
            fromfile="before.md",
            tofile="after.md",
        )
    )

    task.title = new_title
    task.content = new_content
    task.last_modified_at = datetime.now(timezone.utc).replace(tzinfo=None)

    if diff or new_title != old_title:
        change = TaskChange(
            task_id=task_id,
            author_user_id=user.user_id,
            author_role_id=member.team_role_id,
            change_date=date.today(),
            change_time=datetime.now().time().replace(microsecond=0),
            diff_content=diff or f"Заголовок: {old_title} -> {new_title}",
        )
        db.add(change)

    db.commit()
    db.refresh(task)
    return serialize_task(task)

@router.post("/tasks/{task_id}/complete")
def complete_task(task_id: int, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    if task.assignee_user_id != user.user_id:
        raise HTTPException(status_code=409, detail="Эту задачу редактирует другой участник")

    done_status = get_lookup_by_name(db, TaskStatus, "завершена")
    task.task_status_id = done_status.task_status_id
    task.assignee_user_id = None
    task.last_modified_at = datetime.now(timezone.utc).replace(tzinfo=None)

    notify_team(db, task.team_id, task_id, f"Задача «{task.title}» завершена", user.user_id)
    db.commit()
    db.refresh(task)
    return serialize_task(task)

@router.post("/tasks/{task_id}/unlock")
def owner_unlock_task(task_id: int, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды")
    unlock_task_orm(db, task)
    db.commit()
    db.refresh(task)
    return serialize_task(task)

@router.post("/tasks/{task_id}/archive")
def archive_task(task_id: int, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды")
    task.is_archived = True
    db.commit()
    return {"task_id": task_id, "is_archived": True}

@router.get("/tasks/{task_id}/changes")
def list_changes(task_id: int, db: Db, user: CurrentUser):
    task, _ = task_access(db, task_id, user.user_id)
    changes = db.scalars(
        select(TaskChange)
        .where(TaskChange.task_id == task.task_id)
        .order_by(TaskChange.change_date.desc(), TaskChange.change_time.desc())
    ).all()

    return [
        {
            "change_id": c.change_id,
            "task_id": c.task_id,
            "author_user_id": c.author_user_id,
            "author": c.author.nickname,
            "author_role": c.author_role.name,
            "change_date": c.change_date,
            "change_time": c.change_time,
            "diff_content": c.diff_content,
        }
        for c in changes
    ]

@router.get("/tasks/{task_id}/comments")
def list_comments(task_id: int, db: Db, user: CurrentUser):
    task_access(db, task_id, user.user_id)
    comments = db.scalars(
        select(Comment)
        .where(Comment.task_id == task_id)
        .order_by(Comment.created_time)
    ).all()

    return [
        {
            "comment_id": c.comment_id,
            "task_id": c.task_id,
            "author_user_id": c.author_user_id,
            "author": c.author.nickname,
            "text": c.text,
            "created_time": c.created_time,
        }
        for c in comments
    ]

@router.post("/tasks/{task_id}/comments", status_code=status.HTTP_201_CREATED)
def add_comment(task_id: int, data: CommentInput, db: Db, user: CurrentUser):
    _, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    comment = Comment(
        task_id=task_id,
        author_user_id=user.user_id,
        text=data.text,
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return {"comment_id": comment.comment_id, "task_id": task_id, "text": comment.text}

@router.get("/tasks/{task_id}/remarks")
def list_remarks(task_id: int, db: Db, user: CurrentUser):
    task_access(db, task_id, user.user_id)
    remarks = db.scalars(
        select(Remark)
        .where(Remark.task_id == task_id)
        .order_by(Remark.sent_time.desc())
    ).all()

    return [
        {
            "remark_id": r.remark_id,
            "task_id": r.task_id,
            "change_id": r.change_id,
            "author_user_id": r.author_user_id,
            "author": r.author.nickname,
            "fragment_identifier": r.fragment_identifier,
            "text": r.text,
            "sent_time": r.sent_time,
            "status": r.status.name,
        }
        for r in remarks
    ]

@router.post("/tasks/{task_id}/remarks", status_code=status.HTTP_201_CREATED)
def add_remark(task_id: int, data: RemarkInput, db: Db, user: CurrentUser):
    task, member = task_access(db, task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    change = None
    if data.change_id is not None:
        change = db.scalar(
            select(TaskChange).filter_by(change_id=data.change_id, task_id=task_id)
        )
        if change is None:
            raise HTTPException(status_code=404, detail="Версия задачи не найдена")

    assignee_user_id = task.assignee_user_id
    if assignee_user_id is None and change is not None:
        assignee_user_id = change.author_user_id

    open_status = get_lookup_by_name(db, RemarkStatus, "открыто")
    rework_status = get_lookup_by_name(db, TaskStatus, "на доработке")

    remark = Remark(
        task_id=task_id,
        change_id=data.change_id,
        author_user_id=user.user_id,
        fragment_identifier=data.fragment_identifier,
        text=data.text,
        remark_status_id=open_status.remark_status_id,
    )
    db.add(remark)

    task.task_status_id = rework_status.task_status_id
    task.assignee_user_id = assignee_user_id

    if assignee_user_id and assignee_user_id != user.user_id:
        notify(db, assignee_user_id, task_id, f"Новое замечание к задаче «{task.title}»")

    db.commit()
    db.refresh(remark)
    return {"remark_id": remark.remark_id, "task_id": task_id, "status": "открыто"}

@router.patch("/remarks/{remark_id}")
def resolve_remark(remark_id: int, db: Db, user: CurrentUser):
    remark = db.get(Remark, remark_id)
    if not remark:
        raise HTTPException(status_code=404, detail="Замечание не найдено")

    task, member = task_access(db, remark.task_id, user.user_id)
    require_role(member, "владелец команды", "участник")

    if user.user_id != remark.author_user_id and task.assignee_user_id != user.user_id:
        require_role(member, "владелец команды")

    resolved_status = get_lookup_by_name(db, RemarkStatus, "устранено")
    remark.remark_status_id = resolved_status.remark_status_id
    db.commit()
    return {"remark_id": remark_id, "status": "устранено"}


@router.get("/tasks/{task_id}/export")
def export_task(task_id: int, db: Db, user: CurrentUser):
    task, _ = task_access(db, task_id, user.user_id)
    filename = re.sub(r"[^a-zA-Z0-9_-]+", "-", task.title).strip("-") or f"task-{task_id}"
    return Response(
        content=f"# {task.title}\n\n{task.content or ''}",
        media_type="text/markdown",
        headers={"Content-Disposition": f'attachment; filename="{filename}.md"'},
    )
