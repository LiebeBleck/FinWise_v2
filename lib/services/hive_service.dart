import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/budget.dart';

class HiveService {
  static const String userBoxName = 'user';
  static const String categoriesBoxName = 'categories';
  static const String transactionsBoxName = 'transactions';
  static const String budgetBoxName = 'budget';
  static const String keywordsBoxName = 'category_keywords';

  /// Инициализация Hive
  static Future<void> init() async {
    // Инициализация Hive Flutter
    await Hive.initFlutter();

    // Регистрация адаптеров
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(BudgetAdapter());

    // Открытие boxes
    await Hive.openBox<User>(userBoxName);
    await Hive.openBox<Category>(categoriesBoxName);
    await Hive.openBox<Transaction>(transactionsBoxName);
    await Hive.openBox<Budget>(budgetBoxName);
    await Hive.openBox<Map>(keywordsBoxName);

    // Инициализация категорий по умолчанию
    await _initDefaultCategories();
  }

  /// Инициализация предустановленных категорий
  static Future<void> _initDefaultCategories() async {
    final categoriesBox = Hive.box<Category>(categoriesBoxName);

    // Если категорий нет, добавляем предустановленные
    if (categoriesBox.isEmpty) {
      final defaultCategories = Category.getDefaultCategories();
      for (var category in defaultCategories) {
        await categoriesBox.put(category.id, category);
      }
      print('✅ Инициализировано ${defaultCategories.length} категорий по умолчанию');
    }
  }

  /// Получить box пользователя
  static Box<User> get userBox => Hive.box<User>(userBoxName);

  /// Получить box категорий
  static Box<Category> get categoriesBox => Hive.box<Category>(categoriesBoxName);

  /// Получить box транзакций
  static Box<Transaction> get transactionsBox => Hive.box<Transaction>(transactionsBoxName);

  /// Получить box бюджета
  static Box<Budget> get budgetBox => Hive.box<Budget>(budgetBoxName);

  /// Получить box ключевых слов
  static Box<Map> get keywordsBox => Hive.box<Map>(keywordsBoxName);

  /// Получить пользователя (или создать нового)
  static Future<User> getOrCreateUser() async {
    final box = userBox;

    if (box.isEmpty) {
      // Создаём нового пользователя с дефолтными настройками
      final user = User(
        username: 'Пользователь',
        currency: 'RUB',
        timezone: 'Europe/Moscow',
        theme: 'light',
      );
      await box.add(user);
      print('✅ Создан новый пользователь');
      return user;
    }

    return box.getAt(0)!;
  }

  /// Очистка всех данных (для тестирования)
  static Future<void> clearAll() async {
    await userBox.clear();
    await categoriesBox.clear();
    await transactionsBox.clear();
    await budgetBox.clear();
    await keywordsBox.clear();

    // Переинициализация категорий
    await _initDefaultCategories();

    print('🗑️ Все данные очищены');
  }
}
