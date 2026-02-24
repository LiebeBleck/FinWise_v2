"""
Сервис предобработки изображений для улучшения качества OCR.

Pipeline:
1. Декодирование base64 → numpy array
2. Конвертация в оттенки серого
3. Масштабирование (если изображение слишком маленькое)
4. Удаление шума (fastNlMeansDenoising)
5. Улучшение контраста (CLAHE)
6. Бинаризация (адаптивный порог Otsu)
7. Коррекция угла наклона (deskew)

Ожидаемое улучшение точности OCR: 60-70% → 85-95%
"""
import base64
from io import BytesIO

import cv2
import numpy as np
from PIL import Image
from loguru import logger


class ImagePreprocessingService:
    """Предобработка изображений для OCR"""

    # Минимальное разрешение для хорошего OCR (px)
    MIN_WIDTH = 1000
    MIN_HEIGHT = 1000

    def preprocess_from_base64(self, image_base64: str) -> np.ndarray:
        """
        Полный pipeline предобработки из base64 строки.

        Returns:
            numpy array (grayscale, бинаризованное изображение)
        """
        img = self._decode_base64(image_base64)
        img = self._to_grayscale(img)
        img = self._scale_up(img)
        img = self._denoise(img)
        img = self._enhance_contrast(img)
        img = self._binarize(img)
        img = self._deskew(img)
        return img

    def preprocess_to_pil(self, image_base64: str) -> Image.Image:
        """Вернуть предобработанное изображение как PIL Image (для pytesseract)."""
        processed = self.preprocess_from_base64(image_base64)
        return Image.fromarray(processed)

    # ------------------------------------------------------------------
    # Приватные методы pipeline
    # ------------------------------------------------------------------

    def _decode_base64(self, image_base64: str) -> np.ndarray:
        """Декодировать base64 → numpy array (BGR)."""
        # Убираем data URI prefix если есть: "data:image/jpeg;base64,..."
        if "," in image_base64:
            image_base64 = image_base64.split(",", 1)[1]

        image_bytes = base64.b64decode(image_base64)
        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        img = np.array(pil_image)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        logger.debug(f"Decoded image: {img.shape[1]}x{img.shape[0]}px")
        return img

    def _to_grayscale(self, img: np.ndarray) -> np.ndarray:
        """Конвертировать BGR → grayscale."""
        if len(img.shape) == 3:
            return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return img

    def _scale_up(self, img: np.ndarray) -> np.ndarray:
        """
        Масштабировать изображение вверх если оно меньше минимального.
        Маленькие изображения плохо распознаются Tesseract.
        """
        h, w = img.shape[:2]
        if w < self.MIN_WIDTH or h < self.MIN_HEIGHT:
            scale = max(self.MIN_WIDTH / w, self.MIN_HEIGHT / h)
            new_w = int(w * scale)
            new_h = int(h * scale)
            img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
            logger.debug(f"Scaled up: {w}x{h} → {new_w}x{new_h}")
        return img

    def _denoise(self, img: np.ndarray) -> np.ndarray:
        """
        Удалить шум с помощью Non-Local Means Denoising.
        Эффективно для фотографий чеков с зернистостью.
        """
        return cv2.fastNlMeansDenoising(img, h=10, templateWindowSize=7, searchWindowSize=21)

    def _enhance_contrast(self, img: np.ndarray) -> np.ndarray:
        """
        Улучшить контраст с помощью CLAHE (Contrast Limited Adaptive Histogram Equalization).
        Адаптивный метод — работает лучше обычного equalize для неравномерно освещённых чеков.
        """
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        return clahe.apply(img)

    def _binarize(self, img: np.ndarray) -> np.ndarray:
        """
        Бинаризация: адаптивный порог (лучше Otsu для неравномерного освещения).
        Adaptive Gaussian Threshold работает на локальных блоках изображения.
        """
        return cv2.adaptiveThreshold(
            img,
            maxValue=255,
            adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            thresholdType=cv2.THRESH_BINARY,
            blockSize=11,
            C=2,
        )

    def _deskew(self, img: np.ndarray) -> np.ndarray:
        """
        Коррекция угла наклона (deskew).

        Алгоритм:
        1. Найти координаты ненулевых пикселей
        2. Вычислить угол наклона через minAreaRect
        3. Если угол > 0.5° — повернуть изображение
        """
        # Инвертируем: текст должен быть белым на чёрном для minAreaRect
        inverted = cv2.bitwise_not(img)
        coords = np.column_stack(np.where(inverted > 0))

        if len(coords) < 50:
            logger.debug("Not enough points for deskew, skipping")
            return img

        angle = cv2.minAreaRect(coords)[-1]

        # minAreaRect возвращает угол в диапазоне [-90, 0)
        # Корректируем до [-45, 45]
        if angle < -45:
            angle = 90 + angle
        else:
            angle = -angle  # cv2 использует противоположное направление

        if abs(angle) < 0.5:
            logger.debug(f"Skew angle {angle:.2f}° is negligible, skipping")
            return img

        logger.debug(f"Correcting skew angle: {angle:.2f}°")
        h, w = img.shape[:2]
        center = (w // 2, h // 2)
        rotation_matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(
            img,
            rotation_matrix,
            (w, h),
            flags=cv2.INTER_CUBIC,
            borderMode=cv2.BORDER_REPLICATE,
        )
        return rotated


# Singleton instance
image_preprocessing_service = ImagePreprocessingService()
