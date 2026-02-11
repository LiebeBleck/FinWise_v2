from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger

from app.config import settings
from app.api.v1 import ml, receipts, analytics

# Инициализация FastAPI
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Инициализация при запуске"""
    logger.info(f"🚀 Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"📊 Debug mode: {settings.DEBUG}")

    # Инициализация БД
    try:
        from app.db import init_db
        logger.info("📦 Initializing database...")
        await init_db()
        logger.info("✅ Database initialized")
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        # Don't crash the app, just log the error

    # TODO: Инициализация Redis, загрузка ML моделей


@app.on_event("shutdown")
async def shutdown_event():
    """Очистка при остановке"""
    logger.info("👋 Shutting down FinWise API")


@app.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# Подключение роутеров API v1
app.include_router(ml.router, prefix="/api/v1/ml", tags=["ML"])
app.include_router(receipts.router, prefix="/api/v1/receipts", tags=["Receipts"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])


# Обработка ошибок
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Global exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        workers=settings.WORKERS if not settings.DEBUG else 1,
    )
