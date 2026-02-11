from sqlalchemy import Column, String, Integer, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base import Base


class Category(Base):
    """
    Модель категории транзакций
    Поддерживает как предустановленные, так и пользовательские категории
    """
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)

    name = Column(String(100), nullable=False)
    color = Column(String(7), nullable=False)  # Hex color, e.g. #F97316
    icon = Column(String(50), nullable=True)  # Icon name/code
    is_default = Column(Boolean, default=False, nullable=False)  # Предустановленная категория

    # Relationships
    user = relationship("User", back_populates="categories")
    transactions = relationship("Transaction", back_populates="category")

    def __repr__(self):
        return f"<Category(id={self.id}, name={self.name}, is_default={self.is_default})>"
