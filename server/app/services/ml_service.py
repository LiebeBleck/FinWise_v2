"""
ML Service для категоризации транзакций
"""
import pickle
import os
from pathlib import Path
from typing import Dict, List, Tuple
import numpy as np
from loguru import logger


class MLCategorizationService:
    """Сервис для ML категоризации транзакций"""

    def __init__(self):
        self.model = None
        self.vectorizer = None
        self.label_encoder = None
        self.is_loaded = False
        self.model_path = Path(__file__).parent.parent / "ml" / "models"

    def load_model(self):
        """Загрузить обученную модель из файла"""
        try:
            model_file = self.model_path / "categorization_model.pkl"
            vectorizer_file = self.model_path / "vectorizer.pkl"
            encoder_file = self.model_path / "label_encoder.pkl"

            if not model_file.exists():
                logger.warning(f"Model file not found: {model_file}")
                logger.warning("ML categorization will not be available. Please train the model first.")
                return False

            with open(model_file, "rb") as f:
                self.model = pickle.load(f)

            with open(vectorizer_file, "rb") as f:
                self.vectorizer = pickle.load(f)

            with open(encoder_file, "rb") as f:
                self.label_encoder = pickle.load(f)

            self.is_loaded = True
            logger.info("✅ ML categorization model loaded successfully")
            return True

        except Exception as e:
            logger.error(f"Error loading ML model: {e}")
            return False

    def categorize(
        self,
        description: str,
        amount: float,
        merchant_name: str = None,
        items: List[str] = None
    ) -> Tuple[str, float, List[Dict[str, float]]]:
        """
        Категоризировать транзакцию

        Args:
            description: Описание транзакции
            amount: Сумма
            merchant_name: Название магазина (опционально)
            items: Список товаров (опционально)

        Returns:
            (category, confidence, alternatives)
        """
        if not self.is_loaded:
            logger.warning("Model not loaded, using fallback categorization")
            return self._fallback_categorization(description, amount)

        try:
            # Объединяем все текстовые данные
            full_text = description.lower()
            if merchant_name:
                full_text += " " + merchant_name.lower()
            if items:
                full_text += " " + " ".join(items).lower()

            # Векторизация текста
            text_vector = self.vectorizer.transform([full_text])

            # Предсказание
            probabilities = self.model.predict_proba(text_vector)[0]
            predicted_idx = np.argmax(probabilities)
            confidence = float(probabilities[predicted_idx])

            # Основная категория
            category = self.label_encoder.inverse_transform([predicted_idx])[0]

            # Альтернативные категории (топ-3)
            top_indices = np.argsort(probabilities)[-3:][::-1]
            alternatives = []
            for idx in top_indices[1:]:  # Пропускаем первую (основную)
                alt_category = self.label_encoder.inverse_transform([idx])[0]
                alt_confidence = float(probabilities[idx])
                if alt_confidence > 0.05:  # Только если confidence > 5%
                    alternatives.append({
                        "category": alt_category,
                        "confidence": alt_confidence
                    })

            logger.info(f"Categorized '{description}' as '{category}' with confidence {confidence:.2f}")
            return category, confidence, alternatives

        except Exception as e:
            logger.error(f"Error during categorization: {e}")
            return self._fallback_categorization(description, amount)

    def _fallback_categorization(
        self,
        description: str,
        amount: float
    ) -> Tuple[str, float, List[Dict[str, float]]]:
        """
        Fallback категоризация на основе ключевых слов
        Используется когда ML модель недоступна
        """
        desc_lower = description.lower()

        # Словарь ключевых слов
        keywords = {
            "Продукты": ["пятерочка", "магнит", "лента", "дикси", "перекресток", "продукты", "молоко", "хлеб"],
            "Топливо (АЗС)": ["азс", "лукойл", "роснефть", "газпром", "shell", "бензин", "топливо", "аи-"],
            "Рестораны и кафе": ["макдональд", "бургер", "kfc", "кофе", "ресторан", "кафе", "пицца", "суши"],
            "Такси": ["такси", "яндекс.такси", "uber", "gett", "ситимобил"],
            "Транспорт": ["метро", "тройка", "электричка", "автобус", "проездной"],
            "Подписки": ["netflix", "spotify", "youtube", "подписка", "яндекс.плюс", "okko"],
            "Аптека": ["аптека", "лекарство", "ригла", "36.6", "медикамент"],
            "Интернет и связь": ["мтс", "билайн", "мегафон", "ростелеком", "интернет", "связь", "телефон"],
            "Одежда и обувь": ["ozon одежда", "wildberries", "zara", "h&m", "одежда", "обувь", "кроссовки"],
            "Спорт и фитнес": ["спортмастер", "фитнес", "worldclass", "бассейн", "тренажер"],
            "Развлечения": ["кино", "театр", "концерт", "музей", "парк", "аттракцион"],
            "Дом и ремонт": ["леруа", "ikea", "obi", "ремонт", "мебель", "инструмент"],
            "Электроника": ["dns", "м.видео", "связной", "эльдорадо", "ноутбук", "телефон", "наушники"],
            "Образование": ["курс", "университет", "учебник", "книга", "образование"],
            "Коммунальные услуги": ["жкх", "коммунальные", "электричество", "вода", "газ"],
            "Путешествия": ["booking", "aviasales", "билет", "отель", "путешеств"],
            "Красота и здоровье": ["летуаль", "косметика", "салон", "маникюр", "парфюм"],
        }

        # Поиск совпадений
        for category, words in keywords.items():
            for word in words:
                if word in desc_lower:
                    return category, 0.70, [{"category": "Прочее", "confidence": 0.20}]

        # Default fallback
        return "Прочее", 0.30, []


# Singleton instance
ml_service = MLCategorizationService()
