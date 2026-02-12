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
# 28 категорий: 18 расходов + 9 доходов + 1 универсальная
DEFAULT_CATEGORIES = [
    # Расходы
    {"id": 1, "name": "Продукты", "color": "#4CAF50", "icon": "shopping_cart", "is_default": True, "type": "expense"},
    {"id": 2, "name": "Рестораны и кафе", "color": "#FF9800", "icon": "restaurant", "is_default": True, "type": "expense"},
    {"id": 3, "name": "Транспорт", "color": "#2196F3", "icon": "directions_car", "is_default": True, "type": "expense"},
    {"id": 4, "name": "Такси", "color": "#FFC107", "icon": "local_taxi", "is_default": True, "type": "expense"},
    {"id": 5, "name": "Топливо (АЗС)", "color": "#9C27B0", "icon": "local_gas_station", "is_default": True, "type": "expense"},
    {"id": 6, "name": "Коммунальные услуги", "color": "#795548", "icon": "water_drop", "is_default": True, "type": "expense"},
    {"id": 7, "name": "Интернет и связь", "color": "#00BCD4", "icon": "wifi", "is_default": True, "type": "expense"},
    {"id": 8, "name": "Подписки", "color": "#E91E63", "icon": "subscriptions", "is_default": True, "type": "expense"},
    {"id": 9, "name": "Одежда и обувь", "color": "#673AB7", "icon": "checkroom", "is_default": True, "type": "expense"},
    {"id": 10, "name": "Красота и здоровье", "color": "#F06292", "icon": "face", "is_default": True, "type": "expense"},
    {"id": 11, "name": "Аптека", "color": "#EF5350", "icon": "local_pharmacy", "is_default": True, "type": "expense"},
    {"id": 12, "name": "Спорт и фитнес", "color": "#66BB6A", "icon": "fitness_center", "is_default": True, "type": "expense"},
    {"id": 13, "name": "Развлечения", "color": "#AB47BC", "icon": "movie", "is_default": True, "type": "expense"},
    {"id": 14, "name": "Путешествия", "color": "#42A5F5", "icon": "flight", "is_default": True, "type": "expense"},
    {"id": 15, "name": "Образование", "color": "#5C6BC0", "icon": "school", "is_default": True, "type": "expense"},
    {"id": 16, "name": "Дом и ремонт", "color": "#8D6E63", "icon": "home", "is_default": True, "type": "expense"},
    {"id": 17, "name": "Электроника", "color": "#78909C", "icon": "devices", "is_default": True, "type": "expense"},
    {"id": 18, "name": "Благотворительность", "color": "#26C6DA", "icon": "volunteer_activism", "is_default": True, "type": "expense"},

    # Универсальная
    {"id": 19, "name": "Прочее", "color": "#9E9E9E", "icon": "more_horiz", "is_default": True, "type": "both"},

    # Доходы
    {"id": 20, "name": "Зарплата", "color": "#4CAF50", "icon": "attach_money", "is_default": True, "type": "income"},
    {"id": 21, "name": "Фриланс", "color": "#8BC34A", "icon": "work", "is_default": True, "type": "income"},
    {"id": 22, "name": "Инвестиции", "color": "#CDDC39", "icon": "trending_up", "is_default": True, "type": "income"},
    {"id": 23, "name": "Подарки", "color": "#EC407A", "icon": "card_giftcard", "is_default": True, "type": "income"},
    {"id": 24, "name": "Бонусы/Премии", "color": "#FFD700", "icon": "stars", "is_default": True, "type": "income"},
    {"id": 25, "name": "Аренда", "color": "#FF9800", "icon": "home_work", "is_default": True, "type": "income"},
    {"id": 26, "name": "Возврат средств", "color": "#03A9F4", "icon": "currency_exchange", "is_default": True, "type": "income"},
    {"id": 27, "name": "Продажа", "color": "#9C27B0", "icon": "sell", "is_default": True, "type": "income"},
    {"id": 28, "name": "Кэшбэк", "color": "#00BCD4", "icon": "savings", "is_default": True, "type": "income"},
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
