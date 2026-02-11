from fastapi import APIRouter, HTTPException
from loguru import logger
import time

from app.schemas.ml_request import (
    CategorizationRequest,
    CategorizationResponse,
    ForecastRequest,
    ForecastResponse,
    AnomalyDetectionRequest,
    AnomalyDetectionResponse,
    RecommendationsRequest,
    RecommendationsResponse,
)

router = APIRouter()


@router.post("/categorize", response_model=CategorizationResponse)
async def categorize_transaction(request: CategorizationRequest):
    """
    Категоризация транзакции с помощью ML модели

    Алгоритм:
    1. Векторизация текста описания (TF-IDF)
    2. Извлечение признаков (сумма, время, день недели)
    3. Предсказание через Random Forest
    4. Возврат категории с confidence score
    """
    start_time = time.time()

    try:
        # TODO: Загрузить модель и сделать предсказание
        # Временная заглушка:
        category = "Продукты"  # Примерная категоризация
        confidence = 0.85

        # Имитация обработки
        processing_time = int((time.time() - start_time) * 1000)

        return CategorizationResponse(
            category=category,
            confidence=confidence,
            alternatives=[
                {"category": "Прочее", "confidence": 0.10},
                {"category": "Дом и ремонт", "confidence": 0.05}
            ],
            processing_time_ms=processing_time
        )

    except Exception as e:
        logger.error(f"Categorization error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/categorize-batch", response_model=list[CategorizationResponse])
async def categorize_batch(requests: list[CategorizationRequest]):
    """
    Пакетная категоризация (для чеков с множеством товаров)
    """
    results = []
    for req in requests:
        result = await categorize_transaction(req)
        results.append(result)
    return results


@router.post("/forecast", response_model=ForecastResponse)
async def forecast_expenses(request: ForecastRequest):
    """
    Прогноз расходов на следующий период

    Использует Prophet для временных рядов
    """
    try:
        # TODO: Реализовать прогнозирование
        return ForecastResponse(
            period=request.period,
            forecast={
                "total": 47000,
                "by_category": {
                    "Продукты": {"amount": 15000, "confidence": 0.88},
                    "Транспорт": {"amount": 5000, "confidence": 0.75},
                }
            },
            trend="stable",
            confidence_interval=[43000, 51000]
        )

    except Exception as e:
        logger.error(f"Forecast error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/detect-anomaly", response_model=AnomalyDetectionResponse)
async def detect_anomaly(request: AnomalyDetectionRequest):
    """
    Определение аномальных трат

    Использует Isolation Forest
    """
    try:
        # TODO: Реализовать детекцию аномалий
        return AnomalyDetectionResponse(
            is_anomaly=False,
            severity="low",
            explanation="Транзакция в пределах нормы"
        )

    except Exception as e:
        logger.error(f"Anomaly detection error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/recommendations", response_model=RecommendationsResponse)
async def get_recommendations(user_id: str):
    """
    Получить персональные рекомендации по оптимизации бюджета
    """
    try:
        # TODO: Реализовать систему рекомендаций
        from app.schemas.ml_request import Recommendation

        return RecommendationsResponse(
            recommendations=[
                Recommendation(
                    type="savings_opportunity",
                    category="Кафе и рестораны",
                    current_spending=8500,
                    potential_savings=3000,
                    confidence=0.82,
                    message="Вы часто обедаете вне дома. Готовка дома 2 раза в неделю сэкономит ~3000₽/месяц",
                    priority="high"
                )
            ],
            budget_health_score=78,
            spending_trend="stable"
        )

    except Exception as e:
        logger.error(f"Recommendations error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
