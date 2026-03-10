"""
Сервис предобработки изображений для улучшения качества OCR.

Pipeline адаптируется под тип изображения:
- Чистый скан/цифровой чек → простой Otsu threshold
- Фото на камеру → полный pipeline (denoise + CLAHE + adaptive threshold + deskew)
"""
import base64
from io import BytesIO

import cv2
import numpy as np
from PIL import Image
from loguru import logger


class ImagePreprocessingService:
    """Предобработка изображений для OCR"""

    MIN_WIDTH = 1200
    MIN_HEIGHT = 1200

    def preprocess_from_base64(self, image_base64: str) -> np.ndarray:
        img = self._decode_base64(image_base64)
        img = self._to_grayscale(img)
        img = self._scale_up(img)

        if self._is_clean_image(img):
            # Чистый скан/скриншот: только пороговая бинаризация
            logger.debug("Clean image detected — using Otsu threshold only")
            img = self._binarize_otsu(img)
        else:
            # Фотография: полный pipeline
            logger.debug("Photo image detected — using full pipeline")
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
    # Определение типа изображения
    # ------------------------------------------------------------------

    def _is_clean_image(self, gray: np.ndarray) -> bool:
        """
        Определяет, является ли изображение чистым (скан, скриншот, цифровой чек)
        или фотографией (камера телефона с неравномерным освещением).

        Принцип: чистые изображения имеют >85% пикселей около чёрного или белого.
        """
        total = float(gray.size)
        hist = cv2.calcHist([gray], [0], None, [256], [0, 256])
        # Пиксели близкие к чёрному (0..70) — текст
        dark = float(hist[:70].sum())
        # Пиксели близкие к белому (185..255) — фон
        light = float(hist[185:].sum())
        binary_ratio = (dark + light) / total
        logger.debug(f"Image binary ratio: {binary_ratio:.3f} ({'clean' if binary_ratio > 0.80 else 'photo'})")
        return binary_ratio > 0.80

    # ------------------------------------------------------------------
    # Приватные методы pipeline
    # ------------------------------------------------------------------

    def _decode_base64(self, image_base64: str) -> np.ndarray:
        if "," in image_base64:
            image_base64 = image_base64.split(",", 1)[1]
        image_bytes = base64.b64decode(image_base64)
        pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        img = np.array(pil_image)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        logger.debug(f"Decoded image: {img.shape[1]}x{img.shape[0]}px")
        return img

    def _to_grayscale(self, img: np.ndarray) -> np.ndarray:
        if len(img.shape) == 3:
            return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return img

    def _scale_up(self, img: np.ndarray) -> np.ndarray:
        h, w = img.shape[:2]
        if w < self.MIN_WIDTH or h < self.MIN_HEIGHT:
            scale = max(self.MIN_WIDTH / w, self.MIN_HEIGHT / h)
            new_w = int(w * scale)
            new_h = int(h * scale)
            img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
            logger.debug(f"Scaled up: {w}x{h} → {new_w}x{new_h}")
        return img

    def _binarize_otsu(self, img: np.ndarray) -> np.ndarray:
        """Простая глобальная бинаризация методом Otsu — лучший вариант для чистых изображений."""
        _, binary = cv2.threshold(img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return binary

    def _denoise(self, img: np.ndarray) -> np.ndarray:
        return cv2.fastNlMeansDenoising(img, h=10, templateWindowSize=7, searchWindowSize=21)

    def _enhance_contrast(self, img: np.ndarray) -> np.ndarray:
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        return clahe.apply(img)

    def _binarize(self, img: np.ndarray) -> np.ndarray:
        return cv2.adaptiveThreshold(
            img,
            maxValue=255,
            adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            thresholdType=cv2.THRESH_BINARY,
            blockSize=11,
            C=2,
        )

    def _deskew(self, img: np.ndarray) -> np.ndarray:
        inverted = cv2.bitwise_not(img)
        coords = np.column_stack(np.where(inverted > 0))

        if len(coords) < 50:
            return img

        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = 90 + angle
        else:
            angle = -angle

        if abs(angle) > 10:
            logger.debug(f"Skew angle {angle:.2f}° too large, skipping")
            return img
        if abs(angle) < 0.5:
            return img

        logger.debug(f"Correcting skew: {angle:.2f}°")
        h, w = img.shape[:2]
        center = (w // 2, h // 2)
        M = cv2.getRotationMatrix2D(center, angle, 1.0)
        return cv2.warpAffine(img, M, (w, h), flags=cv2.INTER_CUBIC,
                              borderMode=cv2.BORDER_REPLICATE)


image_preprocessing_service = ImagePreprocessingService()
