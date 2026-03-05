from pydantic import BaseModel
from typing import Optional


class RegisterRequest(BaseModel):
    email: str
    username: str
    password_hash: str   # SHA-256 hex of user's password (computed on client)
    currency: Optional[str] = "RUB"


class LoginRequest(BaseModel):
    email: str
    password_hash: str   # SHA-256 hex of user's password


class AuthResponse(BaseModel):
    token: str
    user_id: str
    username: str
    email: str
