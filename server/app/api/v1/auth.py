from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from loguru import logger

from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, AuthResponse
from app.utils.security import get_password_hash, verify_password, create_access_token

router = APIRouter()


@router.post("/register", response_model=AuthResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """
    Создать нового пользователя.
    password_hash — SHA-256 hex пароля (вычисляется на клиенте).
    На сервере дополнительно хэшируется через bcrypt.
    """
    result = await db.execute(select(User).where(User.email == req.email))
    existing = result.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        username=req.username,
        email=req.email,
        hashed_password=get_password_hash(req.password_hash),
        currency=req.currency or "RUB",
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(str(user.id))
    logger.info(f"New user registered: {user.email}")
    return AuthResponse(
        token=token,
        user_id=str(user.id),
        username=user.username,
        email=user.email,
    )


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Войти в аккаунт. Возвращает JWT-токен.
    """
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()
    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(req.password_hash, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(str(user.id))
    logger.info(f"User logged in: {user.email}")
    return AuthResponse(
        token=token,
        user_id=str(user.id),
        username=user.username,
        email=user.email,
    )
