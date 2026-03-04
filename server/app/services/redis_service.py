"""Async Redis client с graceful degradation при недоступном Redis."""
import hashlib
import json
from typing import Optional

from loguru import logger

try:
    import redis.asyncio as aioredis
    _HAS_REDIS = True
except ImportError:
    _HAS_REDIS = False


class RedisService:
    """Singleton-обёртка над async Redis. При недоступности работает без кэша."""

    def __init__(self):
        self._client: Optional[object] = None

    async def init(self, url: str) -> None:
        if not _HAS_REDIS:
            logger.warning("⚠️  redis package not available, running without cache")
            return
        try:
            self._client = aioredis.from_url(url, decode_responses=True, socket_connect_timeout=2)
            await self._client.ping()
            logger.info("✅ Redis connected")
        except Exception as e:
            logger.warning(f"⚠️  Redis unavailable, running without cache: {e}")
            self._client = None

    async def close(self) -> None:
        if self._client:
            try:
                await self._client.aclose()
            except Exception:
                pass
            self._client = None

    async def get(self, key: str) -> Optional[dict]:
        if not self._client:
            return None
        try:
            value = await self._client.get(key)
            if value:
                return json.loads(value)
        except Exception as e:
            logger.warning(f"Redis get error: {e}")
        return None

    async def set(self, key: str, value: dict, ttl: int = 3600) -> None:
        if not self._client:
            return
        try:
            await self._client.set(key, json.dumps(value), ex=ttl)
        except Exception as e:
            logger.warning(f"Redis set error: {e}")

    @staticmethod
    def make_key(description: str, amount: Optional[float], merchant: Optional[str]) -> str:
        raw = f"{description}|{amount}|{merchant}"
        digest = hashlib.md5(raw.encode()).hexdigest()
        return f"ml:cat:{digest}"


redis_service = RedisService()
