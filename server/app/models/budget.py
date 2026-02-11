from sqlalchemy import Column, Float, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime

from app.db.base import Base


class Budget(Base):
    """
    Модель бюджета
    Хранит месячный бюджет пользователя и историю изменений
    """
    __tablename__ = "budgets"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # Бюджет
    monthly_amount = Column(Float, nullable=False)  # Месячный бюджет
    period_start = Column(DateTime, nullable=False, index=True)  # Начало периода
    period_end = Column(DateTime, nullable=True)  # Конец периода (если установлен)

    # Метаданные
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="budgets")

    def __repr__(self):
        return f"<Budget(id={self.id}, monthly_amount={self.monthly_amount}, user_id={self.user_id})>"
