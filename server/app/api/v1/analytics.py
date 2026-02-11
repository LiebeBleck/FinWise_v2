from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, List
from loguru import logger

router = APIRouter()


class SpendingPatternsResponse(BaseModel):
    """Паттерны трат пользователя"""
    average_daily: float
    average_weekly: float
    average_monthly: float
    most_frequent_category: str
    most_expensive_category: str
    peak_spending_hours: List[int]
    peak_spending_days: List[str]


@router.get("/spending-patterns", response_model=SpendingPatternsResponse)
async def get_spending_patterns(user_id: str):
    """
    Получить паттерны трат пользователя
    """
    try:
        # TODO: Реализовать анализ паттернов
        return SpendingPatternsResponse(
            average_daily=1500,
            average_weekly=10500,
            average_monthly=45000,
            most_frequent_category="Продукты",
            most_expensive_category="Транспорт",
            peak_spending_hours=[12, 18, 19],
            peak_spending_days=["Friday", "Saturday", "Sunday"]
        )

    except Exception as e:
        logger.error(f"Spending patterns error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class CategoryBreakdownResponse(BaseModel):
    """Детализация по категориям"""
    categories: Dict[str, dict]
    total_expenses: float
    total_income: float
    net: float


@router.get("/category-breakdown", response_model=CategoryBreakdownResponse)
async def get_category_breakdown(user_id: str, period: str = "month"):
    """
    Детализация по категориям за период
    """
    try:
        # TODO: Реализовать детализацию
        return CategoryBreakdownResponse(
            categories={
                "Продукты": {
                    "amount": 15000,
                    "count": 45,
                    "percentage": 33.3
                },
                "Транспорт": {
                    "amount": 8000,
                    "count": 20,
                    "percentage": 17.8
                }
            },
            total_expenses=45000,
            total_income=50000,
            net=5000
        )

    except Exception as e:
        logger.error(f"Category breakdown error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/compare")
async def compare_with_benchmark(user_id: str):
    """
    Сравнение с анонимными данными других пользователей
    """
    try:
        # TODO: Реализовать сравнение
        return {
            "your_spending": 45000,
            "average_spending": 38000,
            "percentile": 65,
            "comparison": {
                "Продукты": {
                    "you": 15000,
                    "average": 12000,
                    "diff_percent": 25
                }
            }
        }

    except Exception as e:
        logger.error(f"Comparison error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
