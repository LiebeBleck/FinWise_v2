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
from app.services.ml_service import ml_service
from app.services.redis_service import redis_service

router = APIRouter()


@router.post("/categorize", response_model=CategorizationResponse)
async def categorize_transaction(request: CategorizationRequest):
    """
    Категоризация транзакции с помощью ML модели.
    Результат кэшируется в Redis (TTL 1 час).
    """
    # Попытка получить из кэша
    cache_key = redis_service.make_key(
        request.description or "",
        request.amount,
        request.merchant_name,
    )
    cached = await redis_service.get(cache_key)
    if cached is not None:
        cached["processing_time_ms"] = 0
        return CategorizationResponse(**cached)

    start_time = time.time()

    try:
        category, confidence, alternatives = ml_service.categorize(
            description=request.description,
            amount=request.amount,
            merchant_name=request.merchant_name,
            items=request.items,
        )

        processing_time = int((time.time() - start_time) * 1000)

        result = CategorizationResponse(
            category=category,
            confidence=confidence,
            alternatives=alternatives,
            processing_time_ms=processing_time,
        )

        # Кэшируем результат (TTL 1 час)
        await redis_service.set(cache_key, result.model_dump(), ttl=3600)

        return result

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
