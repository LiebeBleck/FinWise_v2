"""
Сервис OCR распознавания текста с чеков.
v5 — барко-формат Пятёрочка/Магнит, 3-decimal суммы, улучшенный парсер.
"""
import re
from datetime import datetime
from typing import Optional

import pytesseract
from loguru import logger

from app.services.image_preprocessing_service import image_preprocessing_service


# PSM 6 = единый блок текста (лучше для чеков)
TESSERACT_CONFIG = "--psm 6 --oem 3 -c preserve_interword_spaces=1"
TESSERACT_LANG = "rus+eng"


class OCRService:

    def recognize(self, image_base64: str) -> dict:
        logger.info("Starting image preprocessing...")
        pil_image = image_preprocessing_service.preprocess_to_pil(image_base64)

        logger.info("Running Tesseract OCR...")
        raw_text = pytesseract.image_to_string(
            pil_image,
            lang=TESSERACT_LANG,
            config=TESSERACT_CONFIG,
        )
        logger.debug(f"OCR raw text ({len(raw_text)} chars):\n{raw_text[:800]}")

        cleaned_text = self._fix_ocr_errors(raw_text)

        result = self._parse_receipt(cleaned_text)
        result["raw_text"] = cleaned_text
        return result

    # ------------------------------------------------------------------
    # Пост-обработка текста OCR
    # ------------------------------------------------------------------

    def _fix_ocr_errors(self, text: str) -> str:
        vowels = 'уеёиоаыэюяУЕЁИОАЫЭЮЯ'

        # 5 → Б перед гласной (начало токена)
        text = re.sub(r'(?<!\d)5(?=[' + vowels + r'])', 'Б', text)
        # 6 → б перед гласной (не после цифры)
        text = re.sub(r'(?<!\d)6(?=[' + vowels + r'])', 'б', text)
        # Ã → й
        text = re.sub(r'[АA]\u0303|Ã', 'й', text)
        # Убираем пробелы внутри сумм: «1 570.00» → «1570.00»
        text = re.sub(r'(\d)\s{1,2}(\d{3}[.,]\d{2})', r'\1\2', text)
        # =l570 → =1570 (l/L в числовом контексте)
        text = re.sub(r'=\s*[lL](\d{2,})', r'=1\1', text)
        # B/b → 8 в числовом контексте: =B90 → =890
        text = re.sub(r'=\s*[Bb](\d{2,})', r'=8\1', text)
        # S → 5 в числовом контексте: =S570 → =5570
        text = re.sub(r'=\s*S(\d{2,})', r'=5\1', text)

        return text

    # ------------------------------------------------------------------
    # Парсинг чека
    # ------------------------------------------------------------------

    def _parse_receipt(self, text: str) -> dict:
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        total = self._extract_total(lines)
        items = self._extract_items(lines)

        # Кросс-валидация: ИТОГ vs сумма позиций
        # Если позиции читаются корректно, используем их для исправления итога
        if total and items:
            # Фильтруем только «настоящие» позиции (цена < total * 1.5)
            real_items = [i for i in items if i["sum"] < (total or 99999) * 1.5]
            if real_items:
                items_sum = sum(i["sum"] for i in real_items)
                if items_sum > 0 and items_sum != total:
                    # Ищем смещение кратное 1000 (типичная ошибка первой цифры)
                    for shift in (1000, 2000, 3000, -1000):
                        corrected = total - shift
                        if corrected > 0 and abs(corrected - items_sum) / items_sum < 0.1:
                            logger.info(
                                f"Total corrected {total} → {corrected} "
                                f"(items_sum={items_sum:.2f})"
                            )
                            total = corrected
                            break

        # Валидация цен товаров: если цена позиции > итога — первая цифра ошиблась
        if total and total > 0:
            for i, item in enumerate(items):
                if item["sum"] > total:
                    for shift in (2000, 1000, 3000):
                        candidate = item["sum"] - shift
                        if 0 < candidate < total:
                            logger.info(f"Item price corrected: {item['sum']} → {candidate}")
                            items[i] = dict(item, sum=candidate)
                            break

        # Фильтр мусора: убираем позиции, цена которых = итогу (гарбл строки ИТОГ/ПОДЫТОГ)
        if total and total > 0:
            items = [i for i in items if abs(i["sum"] - total) / total > 0.02]

        return {
            "total":    total,
            "date":     self._extract_date(lines),
            "retailer": self._extract_retailer(lines),
            "items":    items,
        }

    def _extract_total(self, lines: list) -> Optional[float]:
        # \b — границы слова, чтобы НЕ совпадало с «ПОДЫТОГ»
        total_keywords = re.compile(
            r'\bитого?\b|к\s*оплат[еи]|total',
            re.IGNORECASE
        )
        # Поддержка 2–3 знаков после запятой (94.000 → 94.00)
        amount_pattern = re.compile(r'[=:\s]?\s*(\d[\d\s]{0,5}\s*[.,]\d{2,3})')

        for line in reversed(lines):
            if total_keywords.search(line):
                m = amount_pattern.search(line)
                if m:
                    return self._parse_amount(m.group(1))

        # Fallback: максимальная сумма (пропускаем НДС / сдача / подытог)
        skip_kw = re.compile(
            r'получен|наличн|сдач|cash|received|ндс|nds|подытог',
            re.IGNORECASE
        )
        amounts = []
        for line in lines:
            if skip_kw.search(line):
                continue
            for m in re.finditer(r'=?\s*(\d[\d\s]{0,5}\s*[.,]\d{2,3})', line):
                v = self._parse_amount(m.group(1))
                if v:
                    amounts.append(v)
        return max(amounts) if amounts else None

    def _extract_date(self, lines: list) -> Optional[str]:
        date_patterns = [
            r'(\d{2}[./]\d{2}[./]\d{4})',          # DD.MM.YYYY
            r'(\d{2}[./]\d{2}[./]\d{2})(?:\s|\b)',  # DD.MM.YY
            r'(\d{4}-\d{2}-\d{2})',                  # YYYY-MM-DD
            r'(\d{4}[./]\d{2}[./]\d{2})',            # YYYY.MM.DD
        ]
        for line in lines:
            for pattern in date_patterns:
                m = re.search(pattern, line)
                if m:
                    parsed = self._parse_date(m.group(1))
                    if parsed:
                        return parsed
        return None

    def _extract_retailer(self, lines: list) -> Optional[str]:
        skip_words = re.compile(
            r'кассов|добро пожалов|чек|место расчет|инн|кkt|рн\s*ккт|'
            r'зн\s*ккт|фн\s*\d|фд\s*\d|фп\s*\d|приход|итог|сумма|'
            r'наличн|сдача|кассир|www\.|http',
            re.IGNORECASE
        )
        # Приоритет 1: кавычки (включая Unicode «», "", "")
        quote_pattern = re.compile(
            r'[\u201c\u00ab"]([^\u201d\u00bb"]{3,})[\u201d\u00bb"]'
        )
        for line in lines[:15]:
            m = quote_pattern.search(line)
            if m:
                return m.group(1).strip()

        # Приоритет 2: ключевые слова заведения (включая сети супермаркетов)
        venue_kw = re.compile(
            r'ресторан|кафе|магазин|супермаркет|гипермаркет|аптека|'
            r'рынок|торгов|shop|store|market|cafe|restaurant|'
            r'пятёрочк|пятерочк|перекрёст|перекрест|магнит|дикси|лента|'
            r'атак|метро|глобус|ашан|карусель|окей|вкусвилл|пятёрк',
            re.IGNORECASE
        )
        for line in lines[:12]:
            if venue_kw.search(line) and not skip_words.search(line):
                cleaned = re.sub(r'^(?:добро пожаловать в\s+)?', '', line, flags=re.IGNORECASE).strip()
                if len(cleaned) > 3:
                    return cleaned

        # Приоритет 3: первая чистая строка
        for line in lines[:8]:
            if not skip_words.search(line) and len(line) >= 4:
                return line.strip()

        return None

    def _extract_items(self, lines: list) -> list:
        items = []
        skip_kw = re.compile(
            r'к оплат|наличн|безналич|сдач|скидк|ндс|nds|'
            r'total|cash|change|discount|кассир|инн|ккт|место расчет|'
            r'приход|добро пожалов|ресторан|кафе|кассов|сумм[аы]|подытог|налог',
            re.IGNORECASE
        )
        # Стоп-маркер: строка ИТОГ/ИТОГО (с возможным = или :)
        total_stop = re.compile(r'^\s*итого?\s*[=:]?\s*[\d\s.,]*\s*$', re.IGNORECASE)
        # Артикул/штрихкод: *1234567 или просто 1234567+ + пробел + текст
        # OCR может добавить цифровой префикс из колонки кол-ва: «4 33419767 Пиво...»
        barcode_re = re.compile(r'^(?:\d+\s+)?\*?\d{5,}\s+(.+)')

        i = 0
        while i < len(lines):
            line = lines[i]

            # Стоп-маркер
            if total_stop.search(line):
                break
            if skip_kw.search(line):
                i += 1
                continue

            # Формат: "Название  890.00*1шт.  =890.00" — берём последнее =XXXX.XX
            m_eq = re.search(r'=\s*(\d[\d\s]{0,5}\s*[.,]\d{2,3})\s*$', line)
            if m_eq:
                price = self._parse_amount(m_eq.group(1))
                if price and price > 0:
                    # Удаляем блок цена*кол
                    name = re.split(r'\s+\d+[\d\s]*[.,][\d\s]*\d+\s*[*×хx]', line)[0].strip()
                    if '  ' in name:
                        name = name.split('  ')[0].strip()
                    name = re.sub(r'[\s=\d.,]+$', '', name).strip()
                    # Убираем артикул в начале
                    name = re.sub(r'^\*?\d{5,}\s*', '', name).strip()
                    looks_like_price = bool(re.match(r'^[\d\s.,=*×хx]+$', name))
                    if len(name) > 2 and not looks_like_price:
                        items.append({"name": name, "sum": price})
                i += 1
                continue

            # Формат штрихкода (Пятёрочка/Магнит):
            #   Строка 1: *3419767 Пиво ZAT.GUS 1.42л  А
            #   Строка 2:  94.000   1.420   0.00   1   94.000
            m_barcode = barcode_re.match(line)
            if m_barcode:
                name = m_barcode.group(1).strip()
                # Убираем хвостовую букву — маркировка НДС (А, Б)
                name = re.sub(r'\s+[А-ЯA-Z]\s*$', '', name).strip()
                # Ищем цену в следующей строке
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    if not total_stop.search(next_line) and not skip_kw.search(next_line):
                        prices_in_next = re.findall(r'\d+[.,]\d{2,3}', next_line)
                        if prices_in_next:
                            # Последнее число в строке — итого за позицию
                            price = self._parse_amount(prices_in_next[-1])
                            if price and price > 0 and len(name) > 2:
                                items.append({"name": name, "sum": price})
                            i += 2
                            continue
                i += 1
                continue

            # Формат: "Название  890.00"  (простой, два+ пробела)
            m_plain = re.match(r'^(.+?)\s{2,}(\d[\d\s]{0,5}\s*[.,]\d{2,3})\s*$', line)
            if m_plain:
                price = self._parse_amount(m_plain.group(2))
                name = m_plain.group(1).strip()
                # Убираем артикул в начале
                name = re.sub(r'^\*?\d{5,}\s*', '', name).strip()
                # Имя выглядит как цена (например "94.00") — пропускаем
                looks_like_price = bool(re.match(r'^[\d\s.,=*×хx]+$', name))
                if price and price > 0 and len(name) > 2 and not looks_like_price:
                    items.append({"name": name, "sum": price})

            i += 1

        return items

    # ------------------------------------------------------------------
    # Вспомогательные методы
    # ------------------------------------------------------------------

    @staticmethod
    def _parse_amount(s: str) -> Optional[float]:
        try:
            cleaned = re.sub(r'\s', '', s).replace(',', '.')
            # 3 знака после запятой (94.000) → усекаем до 2
            if '.' in cleaned:
                parts = cleaned.split('.')
                if len(parts) == 2 and len(parts[1]) == 3:
                    cleaned = f"{parts[0]}.{parts[1][:2]}"
            return float(cleaned)
        except (ValueError, TypeError):
            return None

    def _parse_date(self, date_str: str) -> Optional[str]:
        formats = [
            "%d.%m.%Y", "%d/%m/%Y",
            "%Y-%m-%d", "%Y.%m.%d",
            "%d.%m.%y", "%d/%m/%y",
        ]
        for fmt in formats:
            try:
                dt = datetime.strptime(date_str, fmt)
                # Разумный диапазон: 2010–2030
                if 2010 <= dt.year <= 2030:
                    return dt.strftime("%Y-%m-%d")
            except ValueError:
                continue
        return None


ocr_service = OCRService()
