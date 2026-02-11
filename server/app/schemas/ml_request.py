from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class CategorizationRequest(BaseModel):
    """Запрос на категоризацию транзакции"""
    description: str = Field(..., description="Описание транзакции")
    amount: float = Field(..., description="Сумма транзакции")
    transaction_datetime: datetime = Field(..., description="Дата и время", alias="datetime")
    merchant_name: Optional[str] = Field(None, description="Название магазина")
    items: Optional[List[str]] = Field(None, description="Список товаров из чека")


class CategorizationResponse(BaseModel):
    """Ответ категоризации"""
    category: str = Field(..., description="Определённая категория")
    confidence: float = Field(..., ge=0, le=1, description="Уверенность модели")
    alternatives: List[dict] = Field(default_factory=list, description="Альтернативные категории")
    processing_time_ms: int = Field(..., description="Время обработки в мс")


class ForecastRequest(BaseModel):
    """Запрос на прогноз расходов"""
    user_id: str = Field(..., description="ID пользователя")
    period: str = Field("month", description="Период прогноза: week | month | quarter")
    history_months: int = Field(6, ge=3, le=24, description="Месяцев истории для обучения")


class ForecastResponse(BaseModel):
    """Ответ прогноза"""
    period: str
    forecast: dict
    trend: str = Field(..., description="increasing | stable | decreasing")
    confidence_interval: List[float]


class AnomalyDetectionRequest(BaseModel):
    """Запрос на определение аномалий"""
    transaction: dict
    user_stats: dict


class AnomalyDetectionResponse(BaseModel):
    """Ответ определения аномалий"""
    is_anomaly: bool
    anomaly_type: Optional[str] = None
    severity: str = Field(..., description="low | medium | high")
    explanation: str
    suggestion: Optional[str] = None


class RecommendationsRequest(BaseModel):
    """Запрос на получение рекомендаций"""
    user_id: str


class Recommendation(BaseModel):
    """Одна рекомендация"""
    type: str = Field(..., description="savings_opportunity | subscription_warning | etc")
    category: Optional[str] = None
    current_spending: Optional[float] = None
    potential_savings: Optional[float] = None
    confidence: float = Field(..., ge=0, le=1)
    message: str
    priority: str = Field(..., description="low | medium | high")


class RecommendationsResponse(BaseModel):
    """Ответ с рекомендациями"""
    recommendations: List[Recommendation]
    budget_health_score: int = Field(..., ge=0, le=100)
    spending_trend: str
