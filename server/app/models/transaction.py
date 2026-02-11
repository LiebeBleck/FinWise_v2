from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from datetime import datetime

from app.db.base import Base


class Transaction(Base):
    """
    Модель транзакции (доходы/расходы)
    Хранит историю финансовых операций пользователя
    """
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True)

    # Основные данные
    amount = Column(Float, nullable=False)  # Положительное = доход, отрицательное = расход
    description = Column(Text, nullable=True)
    date = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    # Данные чека (опционально)
    receipt_data = Column(JSONB, nullable=True)  # JSON с данными чека: QR, items, retailer

    # ML метаданные
    ml_category = Column(String(100), nullable=True)  # Категория от ML модели
    ml_confidence = Column(Float, nullable=True)  # Уверенность ML модели (0-1)
    is_anomaly = Column(Boolean, default=False, nullable=False)  # Флаг аномальной транзакции

    # Метаданные синхронизации
    device_id = Column(String(100), nullable=True)  # ID устройства (для синхронизации)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    version = Column(Integer, default=1, nullable=False)  # Версия для разрешения конфликтов

    # Relationships
    user = relationship("User", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")

    @property
    def is_expense(self) -> bool:
        """Является ли транзакция расходом"""
        return self.amount < 0

    @property
    def absolute_amount(self) -> float:
        """Абсолютное значение суммы"""
        return abs(self.amount)

    def __repr__(self):
        return f"<Transaction(id={self.id}, amount={self.amount}, category_id={self.category_id})>"
