"""
Сервис OCR распознавания текста с чеков.

Использует pytesseract (Tesseract OCR) с предобработкой изображений.
После извлечения текста парсит структурированные данные чека:
- Итоговая сумма
- Дата
- Название магазина
- Список товаров
"""
import re
from datetime import datetime
from typing import Optional

import pytesseract
from loguru import logger

from app.services.image_preprocessing_service import image_preprocessing_service


# Конфигурация Tesseract для чеков:
# --psm 6  = Assume a single uniform block of text
# --oem 3  = Default OCR Engine (LSTM + legacy)
TESSERACT_CONFIG = "--psm 6 --oem 3"
TESSERACT_LANG = "rus+eng"


class OCRService:
    """Сервис распознавания текста с чеков"""

    def recognize(self, image_base64: str) -> dict:
        """
        Полный pipeline: предобработка → OCR → парсинг.

        Returns:
            dict с полями: raw_text, total, date, retailer, items
        """
        # 1. Предобработка изображения
        logger.info("Starting image preprocessing...")
        pil_image = image_preprocessing_service.preprocess_to_pil(image_base64)

        # 2. OCR
        logger.info("Running Tesseract OCR...")
        raw_text = pytesseract.image_to_string(
            pil_image,
            lang=TESSERACT_LANG,
            config=TESSERACT_CONFIG,
        )
        logger.debug(f"OCR raw text ({len(raw_text)} chars):\n{raw_text[:500]}")

        # 3. Парсинг структурированных данных
        result = self._parse_receipt(raw_text)
        result["raw_text"] = raw_text
        return result

    # ------------------------------------------------------------------
    # Парсинг чека
    # ------------------------------------------------------------------

    def _parse_receipt(self, text: str) -> dict:
        """Извлечь структурированные данные из текста чека."""
        lines = [line.strip() for line in text.splitlines() if line.strip()]

        return {
            "total": self._extract_total(lines),
            "date": self._extract_date(lines),
            "retailer": self._extract_retailer(lines),
            "items": self._extract_items(lines),
        }

    def _extract_total(self, lines: list[str]) -> Optional[float]:
        """
        Найти итоговую сумму чека.
        Паттерны: ИТОГО, ИТОГ, СУММА, TOTAL, К ОПЛАТЕ
        """
        total_patterns = [
            r"(?:итого|итог|к\s*оплате|сумма|total)[:\s]+(\d+[\.,]\d{2})",
            r"(?:итого|итог|к\s*оплате|сумма|total)[:\s]+(\d+)",
        ]
        for line in reversed(lines):  # Итог обычно в конце чека
            line_lower = line.lower()
            for pattern in total_patterns:
                match = re.search(pattern, line_lower)
                if match:
                    amount_str = match.group(1).replace(",", ".")
                    try:
                        return float(amount_str)
                    except ValueError:
                        continue

        # Fallback: ищем самую большую сумму в чеке
        amounts = self._find_all_amounts(lines)
        return max(amounts) if amounts else None

    def _extract_date(self, lines: list[str]) -> Optional[str]:
        """
        Найти дату в чеке.
        Форматы: DD.MM.YYYY, DD/MM/YYYY, YYYY-MM-DD
        """
        date_patterns = [
            r"(\d{2}[./]\d{2}[./]\d{4})",   # DD.MM.YYYY
            r"(\d{4}[-./]\d{2}[-./]\d{2})",  # YYYY-MM-DD
            r"(\d{2}[./]\d{2}[./]\d{2})",    # DD.MM.YY
        ]
        for line in lines:
            for pattern in date_patterns:
                match = re.search(pattern, line)
                if match:
                    date_str = match.group(1)
                    parsed = self._parse_date(date_str)
                    if parsed:
                        return parsed
        return None

    def _extract_retailer(self, lines: list[str]) -> Optional[str]:
        """
        Извлечь название магазина.
        Обычно находится в первых 3-5 строках чека.
        """
        known_retailers = [
            "пятёрочка", "пятерочка", "магнит", "лента", "перекрёсток",
            "перекресток", "дикси", "ашан", "metro", "spar", "окей",
            "вкусвилл", "Fix Price", "wildberries", "ozon", "яндекс",
            "kfc", "макдональдс", "бургер кинг", "subway", "coffee",
        ]
        # Проверяем первые 5 строк
        for line in lines[:5]:
            line_lower = line.lower()
            for retailer in known_retailers:
                if retailer.lower() in line_lower:
                    return line.strip()
            # Берём первую непустую строку как название магазина
            if len(line) > 3:
                return line.strip()
        return None

    def _extract_items(self, lines: list[str]) -> list[dict]:
        """
        Извлечь позиции товаров из чека.
        Формат строки товара: "Название ... цена"
        """
        items = []
        # Паттерн: строка с суммой в конце (цена товара)
        item_pattern = re.compile(
            r"^(.+?)\s+(\d+[\.,]\d{2})\s*$"
        )
        # Ключевые слова, которые не являются товарами
        skip_keywords = {
            "итого", "итог", "сумма", "к оплате", "наличные",
            "безналичные", "сдача", "скидка", "nds", "ндс",
            "total", "cash", "change", "discount",
        }

        for line in lines:
            line_lower = line.lower()
            if any(kw in line_lower for kw in skip_keywords):
                continue

            match = item_pattern.match(line)
            if match:
                name = match.group(1).strip()
                price_str = match.group(2).replace(",", ".")
                try:
                    price = float(price_str)
                    if price > 0 and len(name) > 2:
                        items.append({"name": name, "sum": price})
                except ValueError:
                    continue

        return items

    # ------------------------------------------------------------------
    # Вспомогательные методы
    # ------------------------------------------------------------------

    def _find_all_amounts(self, lines: list[str]) -> list[float]:
        """Найти все числовые суммы в тексте."""
        pattern = re.compile(r"\b(\d{1,6}[.,]\d{2})\b")
        amounts = []
        for line in lines:
            for match in pattern.finditer(line):
                try:
                    amounts.append(float(match.group(1).replace(",", ".")))
                except ValueError:
                    continue
        return amounts

    def _parse_date(self, date_str: str) -> Optional[str]:
        """Попытаться распарсить дату в ISO формат."""
        formats = [
            "%d.%m.%Y", "%d/%m/%Y",
            "%Y-%m-%d", "%Y.%m.%d",
            "%d.%m.%y", "%d/%m/%y",
        ]
        for fmt in formats:
            try:
                dt = datetime.strptime(date_str, fmt)
                return dt.strftime("%Y-%m-%d")
            except ValueError:
                continue
        return None


# Singleton instance
ocr_service = OCRService()
