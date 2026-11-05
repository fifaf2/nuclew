from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

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
