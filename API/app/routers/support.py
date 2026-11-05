from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.database import Db
from app.dependencies import CurrentUser, support_only
from app.models import SupportRequest
from app.schemas import SupportProcessInput, SupportRequestInput

router = APIRouter(prefix="/api/v1/support", tags=["support"])

@router.post("/requests", status_code=status.HTTP_201_CREATED)
def create_support_request(data: SupportRequestInput, db: Db, user: CurrentUser):
    req = SupportRequest(
        user_id=user.user_id,
        subject=data.subject,
        text=data.text,
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return {"request_id": req.request_id, "subject": req.subject}

@router.get("/requests")
def list_support_requests(db: Db, user: CurrentUser, limit: int = Query(default=50, ge=1, le=100)):
    support_only(user)
    requests = db.scalars(
        select(SupportRequest)
        .order_by(SupportRequest.created_time.desc())
        .limit(limit)
    ).all()

    return [
        {
            "request_id": r.request_id,
            "user_id": r.user_id,
            "subject": r.subject,
            "text": r.text,
            "created_time": r.created_time,
            "processed_time": r.processed_time,
            "processed_by_user_id": r.processed_by_user_id,
            "nickname": r.user.nickname,
            "email": r.user.email,
        }
        for r in requests
    ]

@router.patch("/requests/{request_id}")
def process_support_request(request_id: int, data: SupportProcessInput, db: Db, user: CurrentUser):
    support_only(user)
    req = db.get(SupportRequest, request_id)
    if not req:
        raise HTTPException(status_code=404, detail="Обращение не найдено")

    req.processed_time = datetime.now() if data.processed else None
    req.processed_by_user_id = user.user_id if data.processed else None
    db.commit()
    return {"request_id": request_id, "processed": data.processed}
