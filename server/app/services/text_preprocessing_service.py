"""
NLP предобработка текста для ML категоризации.
Лемматизация + удаление стоп-слов (русский и английский).
"""
import re
from typing import Optional
from loguru import logger

try:
    import pymorphy2
    _morph = pymorphy2.MorphAnalyzer()
    _pymorphy2_available = True
except ImportError:
    _morph = None
    _pymorphy2_available = False
    logger.warning("pymorphy2 не установлен. Лемматизация недоступна, используется только нормализация текста.")


# Стоп-слова: русские + английские
STOP_WORDS = {
    # Русские предлоги, союзы, частицы
    "в", "на", "и", "с", "по", "за", "к", "из", "от", "до", "не", "или",
    "а", "но", "для", "при", "о", "об", "под", "над", "между", "через",
    "без", "во", "со", "да", "же", "ли", "бы", "ни", "уж", "уже",
    "это", "так", "как", "что", "то", "все", "он", "она", "они", "оно",
    "ее", "его", "их", "мне", "ему", "нас", "вас", "им", "нем",
    "был", "была", "были", "быть", "есть", "нет",
    # Английские предлоги и союзы
    "the", "a", "an", "and", "or", "for", "in", "on", "at", "to", "of",
    "is", "it", "be", "are", "was", "by", "with", "from",
}


def _tokenize(text: str) -> list[str]:
    """Разбить текст на токены (только буквы и цифры)."""
    return re.findall(r"[а-яёА-ЯЁa-zA-Z0-9]+", text.lower())


def _lemmatize(word: str) -> str:
    """Привести слово к начальной форме через pymorphy2."""
    if not _pymorphy2_available:
        return word
    parsed = _morph.parse(word)
    if parsed:
        return parsed[0].normal_form
    return word


def preprocess(text: str) -> str:
    """
    Полный pipeline NLP предобработки:
    1. Нижний регистр
    2. Токенизация (только буквы/цифры)
    3. Удаление стоп-слов
    4. Лемматизация (pymorphy2)

    Args:
        text: Исходный текст (описание транзакции)

    Returns:
        Предобработанный текст в виде строки
    """
    if not text:
        return ""

    tokens = _tokenize(text)

    # Удаляем стоп-слова (до лемматизации — быстрее)
    tokens = [t for t in tokens if t not in STOP_WORDS and len(t) > 1]

    # Лемматизация
    if _pymorphy2_available:
        tokens = [_lemmatize(t) for t in tokens]

    return " ".join(tokens)


def preprocess_batch(texts: list[str]) -> list[str]:
    """Предобработать список текстов."""
    return [preprocess(t) for t in texts]


# Singleton-like — функции stateless, объект не нужен
