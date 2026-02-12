"""
Простой тест ML сервиса категоризации
"""
import sys
from pathlib import Path

# Add app to path
sys.path.insert(0, str(Path(__file__).parent))

from app.services.ml_service import ml_service
from loguru import logger

def test_categorization():
    """Тест категоризации различных транзакций"""

    # Загрузка модели
    logger.info("Loading ML model...")
    success = ml_service.load_model()

    if not success or not ml_service.is_loaded:
        logger.error("Model failed to load!")
        return False

    logger.info("✅ Model loaded successfully!\n")

    # Тестовые транзакции
    test_transactions = [
        {"description": "Пятерочка Хлеб Молоко", "amount": 450.0},
        {"description": "Яндекс Такси поездка домой", "amount": 520.0},
        {"description": "Макдональдс обед", "amount": 850.0},
        {"description": "АЗС Лукойл АИ-95", "amount": 2500.0},
        {"description": "Аптека 36.6 лекарства", "amount": 680.0},
        {"description": "Netflix подписка", "amount": 899.0},
        {"description": "Спортмастер кроссовки", "amount": 5600.0},
        {"description": "МТС мобильная связь", "amount": 500.0},
    ]

    # Тестирование
    logger.info("Testing categorization:\n")
    for i, tx in enumerate(test_transactions, 1):
        category, confidence, alternatives = ml_service.categorize(
            description=tx["description"],
            amount=tx["amount"]
        )

        logger.info(f"Test {i}:")
        logger.info(f"  Description: {tx['description']}")
        logger.info(f"  Category: {category} (confidence: {confidence:.2%})")
        if alternatives:
            logger.info(f"  Alternatives: {alternatives}")
        logger.info("")

    logger.info("✅ All tests completed!\n")
    return True


if __name__ == "__main__":
    logger.info("🚀 Starting ML Service Test\n")
    success = test_categorization()

    if success:
        logger.info("✅ Test passed successfully!")
    else:
        logger.error("❌ Test failed!")
        sys.exit(1)
