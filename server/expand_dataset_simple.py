import random

# Генерируем 800 новых примеров для 29 категорий
examples = []

# 1. Продукты (100)
shops = ['Пятёрочка', 'Магнит', 'Перекрёсток', 'Лента', 'Ашан', 'ВкусВилл']
products = ['Хлеб', 'Молоко', 'Мясо', 'Рыба', 'Овощи', 'Фрукты']
for _ in range(100):
    examples.append(f"{random.choice(shops)} {random.choice(products)},{random.randint(200,2000)},Продукты")

# 2. Топливо АЗС (50)
azs = ['Лукойл', 'Роснефть', 'Газпромнефть', 'Татнефть']
for _ in range(50):
    examples.append(f"{random.choice(azs)} АИ-95,{random.randint(2000,4500)},Топливо (АЗС)")

# 3. Кафе и рестораны (80)
cafes = ['МакДональдс', 'KFC', 'Додо Пицца', 'Subway', 'Теремок']
for _ in range(80):
    examples.append(f"{random.choice(cafes)} Заказ,{random.randint(300,2000)},Кафе и рестораны")

# 4. Такси (60)
taxi_apps = ['Яндекс Такси', 'Uber', 'Gett', 'Ситимобил']
for _ in range(60):
    examples.append(f"{random.choice(taxi_apps)} Поездка,{random.randint(200,1500)},Такси")

# 5. Транспорт (40)
transport = ['Метро', 'Тройка', 'Электричка', 'Автобус']
for _ in range(40):
    examples.append(f"{random.choice(transport)} Проезд,{random.randint(100,2000)},Транспорт")

# 6. Здоровье (50)
pharmacies = ['Аптека 36.6', 'Ригла', 'Максавит']
for _ in range(50):
    examples.append(f"{random.choice(pharmacies)} Лекарства,{random.randint(200,1800)},Здоровье")

# 7. Одежда (60)
clothing = ['Wildberries', 'Lamoda', 'Zara', 'H&M']
for _ in range(60):
    examples.append(f"{random.choice(clothing)} Одежда,{random.randint(1000,12000)},Одежда и обувь")

# 8. Спорт (40)
sport = ['WorldClass', 'FitnesHouse', 'X-Fit', 'Бассейн']
for _ in range(40):
    examples.append(f"{random.choice(sport)} Абонемент,{random.randint(2000,50000)},Спорт и фитнес")

# 9. Развлечения (50)
entertainment = ['Кинотеатр', 'Театр', 'Музей', 'Квест']
for _ in range(50):
    examples.append(f"{random.choice(entertainment)} Билет,{random.randint(500,3000)},Развлечения")

# 10. Дом и быт (60)
home_stores = ['Леруа Мерлен', 'IKEA', 'Fix Price', 'М.Видео']
for _ in range(60):
    examples.append(f"{random.choice(home_stores)} Товары,{random.randint(500,40000)},Дом и быт")

# 11. Образование (40)
education = ['Skillbox', 'Udemy', 'GeekBrains', 'Лабиринт']
for _ in range(40):
    examples.append(f"{random.choice(education)} Курс,{random.randint(1000,20000)},Образование")

# 12. Красота (40)
beauty = ['Л\'Этуаль', 'Рив Гош', 'Салон красоты']
for _ in range(40):
    examples.append(f"{random.choice(beauty)} Услуги,{random.randint(500,6000)},Красота и здоровье")

# 13. Связь и интернет (40)
telecom = ['МТС', 'Билайн', 'Мегафон', 'Ростелеком']
for _ in range(40):
    examples.append(f"{random.choice(telecom)} Связь,{random.randint(300,1000)},Связь и интернет")

# 14. Подписки (30)
subscriptions = ['Netflix', 'Spotify', 'YouTube Premium', 'Яндекс Плюс']
prices = [149, 169, 399, 599, 899]
for _ in range(30):
    examples.append(f"{random.choice(subscriptions)} Подписка,{random.choice(prices)},Подписки")

# 15. Питомцы (40)
pets = ['Зоомагазин', 'Ветклиника', 'Груминг']
for _ in range(40):
    examples.append(f"{random.choice(pets)} Услуги,{random.randint(500,3000)},Питомцы")

# 16. Путешествия (30)
travel = ['Booking.com', 'Aviasales', 'РЖД']
for _ in range(30):
    examples.append(f"{random.choice(travel)} Билет,{random.randint(5000,50000)},Путешествия")

# 17. Подарки и благотворительность (20)
for _ in range(20):
    examples.append(f"Благотворительность,{random.randint(1000,10000)},Подарки и благотворительность")

# 18. Вредные привычки (20)
for _ in range(20):
    examples.append(f"Сигареты,{random.randint(200,600)},Вредные привычки")

# 19. Прочее (10)
for _ in range(10):
    examples.append(f"Прочие расходы,{random.randint(500,5000)},Прочее")

# ДОХОДЫ
# 20. Зарплата (20)
for _ in range(20):
    examples.append(f"Зарплата,{random.randint(50000,150000)},Зарплата")

# 21. Фриланс (20)
for _ in range(20):
    examples.append(f"Фриланс Проект,{random.randint(10000,50000)},Фриланс")

# 22. Подарки доход (15)
for _ in range(15):
    examples.append(f"Подарок на праздник,{random.randint(2000,20000)},Подарки")

# 23. Инвестиции (15)
for _ in range(15):
    examples.append(f"Дивиденды,{random.randint(1000,15000)},Инвестиции")

# 24. Кэшбэк (20)
for _ in range(20):
    examples.append(f"Кэшбэк Тинькофф,{random.randint(500,3000)},Кэшбэк")

# 25. Возврат (15)
for _ in range(15):
    examples.append(f"Возврат товара,{random.randint(1000,10000)},Возврат средств")

# 26. Аренда доход (10)
for _ in range(10):
    examples.append(f"Аренда квартиры,{random.randint(20000,60000)},Аренда")

# 27. Продажа (10)
for _ in range(10):
    examples.append(f"Продажа на Avito,{random.randint(5000,30000)},Продажа")

# 28. Бонусы (15)
for _ in range(15):
    examples.append(f"Бонус Годовой,{random.randint(5000,30000)},Бонусы")

# 29. Переводы (10)
for _ in range(10):
    examples.append(f"Перевод от друга,{random.randint(1000,20000)},Переводы")

print(f"Сгенерировано {len(examples)} новых примеров")

# Добавляем в файл
with open('data/training/transactions_dataset.csv', 'a', encoding='utf-8') as f:
    for ex in examples:
        f.write(ex + '\n')

print("Датасет расширен!")
