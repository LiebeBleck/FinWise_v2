from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from loguru import logger

from app.services.ocr_service import ocr_service

router = APIRouter()


class QRReceiptRequest(BaseModel):
    """Запрос на обработку QR чека"""
    qr_raw: str  # t=20240115T1430&s=1250.00&fn=...


class ReceiptItem(BaseModel):
    """Позиция в чеке"""
    name: str
    price: float
    quantity: int
    sum: float
    auto_category: Optional[str] = None


class QRReceiptResponse(BaseModel):
    """Ответ с данными чека"""
    retailer_name: str
    retailer_inn: str
    items: List[ReceiptItem]
    total: float
    scan_date: str


@router.post("/parse-qr", response_model=QRReceiptResponse)
async def parse_qr_receipt(request: QRReceiptRequest):
    """
    Получить детальные данные чека по QR коду

    Процесс:
    1. Парсинг QR кода (извлечение параметров)
    2. Запрос к API ФНС или proverkacheka.com
    3. Получение списка товаров
    4. ML категоризация каждой позиции
    """
    try:
        # TODO: Реализовать парсинг QR и запрос к API
        # Временная заглушка:
        return QRReceiptResponse(
            retailer_name="Пятёрочка №1234",
            retailer_inn="1234567890",
            items=[
                ReceiptItem(
                    name="Хлеб белый",
                    price=45.50,
                    quantity=1,
                    sum=45.50,
                    auto_category="Продукты"
                ),
                ReceiptItem(
                    name="Молоко 3.2% 1л",
                    price=89.90,
                    quantity=2,
                    sum=179.80,
                    auto_category="Продукты"
                )
            ],
            total=225.30,
            scan_date="2024-01-15T14:30:00"
        )

    except Exception as e:
        logger.error(f"QR parsing error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class OCRReceiptRequest(BaseModel):
    """Запрос на OCR чека"""
    image_base64: str  # Base64 encoded image (JPEG/PNG)


class OCRReceiptResponse(BaseModel):
    """Ответ OCR распознавания чека"""
    total: Optional[float]
    date: Optional[str]
    retailer: Optional[str]
    items: List[dict]
    raw_text: str


@router.post("/ocr", response_model=OCRReceiptResponse)
async def ocr_receipt(request: OCRReceiptRequest):
    """
    Распознать чек через OCR с предобработкой изображения.

    Pipeline предобработки:
    1. Декодирование base64 → numpy array
    2. Конвертация в оттенки серого
    3. Масштабирование (если изображение слишком маленькое)
    4. Удаление шума (fastNlMeansDenoising)
    5. Улучшение контраста (CLAHE)
    6. Бинаризация (адаптивный порог Gaussian)
    7. Коррекция угла наклона (deskew)
    8. Tesseract OCR (rus+eng)
    9. Парсинг: итоговая сумма, дата, магазин, товары
    """
    try:
        result = ocr_service.recognize(request.image_base64)

        return OCRReceiptResponse(
            total=result.get("total"),
            date=result.get("date"),
            retailer=result.get("retailer"),
            items=result.get("items", []),
            raw_text=result.get("raw_text", ""),
        )

    except Exception as e:
        logger.error(f"OCR error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
