from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from typing import Optional
from datetime import datetime
from loguru import logger
import uuid

from app.db.session import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.category import Category
from app.schemas.sync import PushRequest, PullResponse, SyncTransaction, SyncBudget, SyncCategory
from app.utils.security import decode_token

router = APIRouter()

# Key in receipt_data JSON that stores Hive local_id and extra Hive fields
_META_KEY = "_hive"


async def _get_user(authorization: Optional[str], db: AsyncSession) -> User:
    """Extract and validate JWT, return User."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    token = authorization.split(" ", 1)[1]
    user_id = decode_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Token expired or invalid")
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    result = await db.execute(select(User).where(User.id == uid))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@router.post("/push")
async def push_data(
    body: PushRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Клиент отправляет все свои данные на сервер.
    Стратегия: полная замена (client wins) — удаляем старые записи, вставляем новые.
    """
    user = await _get_user(authorization, db)

    # ── Transactions ──────────────────────────────────────
    await db.execute(delete(Transaction).where(Transaction.user_id == user.id))
    for t in body.transactions:
        meta = {
            "local_id": str(t.local_id),
            "is_planned": t.is_planned,
            "planned_date": t.planned_date.isoformat() if t.planned_date else None,
            "is_recurring": t.is_recurring,
            "recurrence_rule": t.recurrence_rule,
            "next_recurrence_date": t.next_recurrence_date.isoformat()
            if t.next_recurrence_date else None,
            "original_receipt": t.receipt_data,
        }
        db.add(Transaction(
            user_id=user.id,
            category_id=t.category_id,
            amount=t.amount,
            description=t.description,
            date=t.date,
            receipt_data={_META_KEY: meta},
        ))

    # ── Budget ────────────────────────────────────────────
    await db.execute(delete(Budget).where(Budget.user_id == user.id))
    if body.budget:
        b = body.budget
        db.add(Budget(
            user_id=user.id,
            monthly_amount=b.monthly_amount,
            period_start=b.period_start,
            period_end=None,
        ))

    # ── Custom categories ─────────────────────────────────
    await db.execute(
        delete(Category).where(
            (Category.user_id == user.id) & (Category.is_default == False)
        )
    )
    for c in body.custom_categories:
        db.add(Category(
            user_id=user.id,
            name=c.name,
            color=c.color,
            type=c.type,
            is_default=False,
        ))

    user.last_sync_at = datetime.utcnow()
    await db.commit()
    logger.info(
        f"Push from user {user.email}: {len(body.transactions)} tx, "
        f"budget={body.budget is not None}, {len(body.custom_categories)} categories"
    )
    return {"status": "ok", "synced_at": user.last_sync_at.isoformat()}


@router.get("/pull", response_model=PullResponse)
async def pull_data(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Клиент запрашивает все свои данные с сервера (восстановление / новое устройство).
    """
    user = await _get_user(authorization, db)

    # Transactions
    tx_result = await db.execute(
        select(Transaction).where(Transaction.user_id == user.id)
    )
    db_txs = tx_result.scalars().all()

    sync_txs = []
    for t in db_txs:
        meta = {}
        receipt_original = None
        if t.receipt_data and _META_KEY in t.receipt_data:
            meta = t.receipt_data[_META_KEY]
            receipt_original = meta.get("original_receipt")

        def _parse_dt(s):
            return datetime.fromisoformat(s) if s else None

        sync_txs.append(SyncTransaction(
            local_id=str(meta.get("local_id", t.id)),
            amount=t.amount,
            category_id=t.category_id or 19,  # fallback to "Прочее"
            description=t.description or "",
            date=t.date,
            is_planned=meta.get("is_planned", False),
            planned_date=_parse_dt(meta.get("planned_date")),
            is_recurring=meta.get("is_recurring", False),
            recurrence_rule=meta.get("recurrence_rule"),
            next_recurrence_date=_parse_dt(meta.get("next_recurrence_date")),
            receipt_data=receipt_original,
        ))

    # Budget
    budget_result = await db.execute(
        select(Budget).where(Budget.user_id == user.id)
    )
    db_budget = budget_result.scalar_one_or_none()
    sync_budget = None
    if db_budget:
        sync_budget = SyncBudget(
            monthly_amount=db_budget.monthly_amount,
            period_start=db_budget.period_start,
        )

    # Custom categories
    cat_result = await db.execute(
        select(Category).where(
            (Category.user_id == user.id) & (Category.is_default == False)
        )
    )
    db_cats = cat_result.scalars().all()
    sync_cats = [
        SyncCategory(
            local_id=c.id,
            name=c.name,
            color=c.color,
            type=c.type,
        )
        for c in db_cats
    ]

    now = datetime.utcnow()
    logger.info(
        f"Pull for user {user.email}: {len(sync_txs)} tx, {len(sync_cats)} categories"
    )
    return PullResponse(
        transactions=sync_txs,
        budget=sync_budget,
        custom_categories=sync_cats,
        synced_at=now,
    )
