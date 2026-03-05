from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime


class SyncTransaction(BaseModel):
    local_id: str   # UUID string (Hive Transaction.id)
    amount: float
    category_id: int
    description: str
    date: datetime
    is_planned: bool = False
    planned_date: Optional[datetime] = None
    is_recurring: bool = False
    recurrence_rule: Optional[str] = None
    next_recurrence_date: Optional[datetime] = None
    receipt_data: Optional[Any] = None


class SyncBudget(BaseModel):
    monthly_amount: float
    period_start: datetime
    period_type: Optional[str] = "monthly"
    category_budgets: Optional[Any] = None   # Map<int,double> as JSON


class SyncCategory(BaseModel):
    local_id: int
    name: str
    color: str
    type: str   # income | expense | both
    is_default: bool = False


class PushRequest(BaseModel):
    transactions: List[SyncTransaction] = []
    budget: Optional[SyncBudget] = None
    custom_categories: List[SyncCategory] = []


class PullResponse(BaseModel):
    transactions: List[SyncTransaction] = []
    budget: Optional[SyncBudget] = None
    custom_categories: List[SyncCategory] = []
    synced_at: datetime
