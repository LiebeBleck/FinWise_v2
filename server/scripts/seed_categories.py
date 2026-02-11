"""
Скрипт для заполнения базы данных предустановленными категориями
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.category import Category


# Предустановленные категории (соответствуют Flutter приложению)
DEFAULT_CATEGORIES = [
    {"id": 1, "name": "Продукты", "color": "#22C55E", "icon": "shopping_cart", "is_default": True},
    {"id": 2, "name": "Транспорт", "color": "#3B82F6", "icon": "directions_car", "is_default": True},
    {"id": 3, "name": "Кафе и рестораны", "color": "#F59E0B", "icon": "restaurant", "is_default": True},
    {"id": 4, "name": "Развлечения", "color": "#EC4899", "icon": "movie", "is_default": True},
    {"id": 5, "name": "Здоровье", "color": "#EF4444", "icon": "local_hospital", "is_default": True},
    {"id": 6, "name": "Одежда", "color": "#8B5CF6", "icon": "checkroom", "is_default": True},
    {"id": 7, "name": "Образование", "color": "#06B6D4", "icon": "school", "is_default": True},
    {"id": 8, "name": "Спорт", "color": "#10B981", "icon": "fitness_center", "is_default": True},
    {"id": 9, "name": "Дом", "color": "#F97316", "icon": "home", "is_default": True},
    {"id": 10, "name": "Связь", "color": "#6366F1", "icon": "phone", "is_default": True},
    {"id": 11, "name": "Подарки", "color": "#DB2777", "icon": "card_giftcard", "is_default": True},
    {"id": 12, "name": "Красота", "color": "#A855F7", "icon": "face", "is_default": True},
    {"id": 13, "name": "Путешествия", "color": "#14B8A6", "icon": "flight", "is_default": True},
    {"id": 14, "name": "Такси", "color": "#0EA5E9", "icon": "local_taxi", "is_default": True},
    {"id": 15, "name": "Аптека", "color": "#DC2626", "icon": "local_pharmacy", "is_default": True},
    {"id": 16, "name": "Подписки", "color": "#7C3AED", "icon": "subscriptions", "is_default": True},
    {"id": 17, "name": "Электроника", "color": "#2563EB", "icon": "devices", "is_default": True},
    {"id": 18, "name": "Книги", "color": "#059669", "icon": "menu_book", "is_default": True},
    {"id": 19, "name": "Зарплата", "color": "#16A34A", "icon": "attach_money", "is_default": True},
    {"id": 20, "name": "Прочее", "color": "#6B7280", "icon": "more_horiz", "is_default": True},
]


async def seed_categories():
    """Заполнить базу предустановленными категориями"""
    async with AsyncSessionLocal() as session:
        try:
            # Проверить, есть ли уже категории
            result = await session.execute(select(Category).where(Category.is_default == True))
            existing_categories = result.scalars().all()

            if existing_categories:
                print(f"✅ Категории уже существуют ({len(existing_categories)} шт.)")
                return

            # Добавить категории
            for cat_data in DEFAULT_CATEGORIES:
                category = Category(**cat_data, user_id=None)
                session.add(category)

            await session.commit()
            print(f"✅ Добавлено {len(DEFAULT_CATEGORIES)} предустановленных категорий")

        except Exception as e:
            print(f"❌ Ошибка при добавлении категорий: {e}")
            await session.rollback()
            raise


if __name__ == "__main__":
    print("🚀 Запуск скрипта заполнения категорий...")
    asyncio.run(seed_categories())
    print("✅ Скрипт завершён")
