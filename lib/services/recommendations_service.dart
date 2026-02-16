import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';

/// Тип рекомендации
enum RecommendationType {
  budgetWarning,     // Превышение бюджета
  inactiveCategory,  // Неактивная категория
  frequentSmall,     // Частые малые покупки
  expensiveCategory, // Дорогая категория
}

/// Модель рекомендации
class Recommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final double? savingsAmount;
  final String category;
  final IconData icon;
  final Color color;

  Recommendation({
    required this.type,
    required this.title,
    required this.description,
    this.savingsAmount,
    required this.category,
    required this.icon,
    required this.color,
  });
}

/// Сервис для генерации персональных рекомендаций
class RecommendationsService {
  /// Генерирует список рекомендаций на основе данных пользователя
  static Future<List<Recommendation>> generateRecommendations() async {
    final recommendations = <Recommendation>[];

    // Открываем Hive boxes
    final transactionsBox = await Hive.openBox<Transaction>('transactions');
    final categoriesBox = await Hive.openBox<Category>('categories');
    final budgetsBox = await Hive.openBox<Budget>('budgets');

    // Получаем выполненные транзакции за последние 30 дней
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final recentTransactions = transactionsBox.values
        .where((tx) =>
            !tx.isPlanned && // Только выполненные
            tx.date.isAfter(thirtyDaysAgo) &&
            tx.date.isBefore(now))
        .toList();

    // 1. Проверка превышения бюджета
    if (budgetsBox.isNotEmpty) {
      final budget = budgetsBox.values.first;
      final expenses = recentTransactions
          .where((tx) => tx.amount < 0)
          .fold<double>(0, (sum, tx) => sum + tx.amount.abs());

      if (expenses > budget.monthlyAmount) {
        final overspent = expenses - budget.monthlyAmount;
        recommendations.add(Recommendation(
          type: RecommendationType.budgetWarning,
          title: '⚠️ Превышение бюджета',
          description: 'Вы потратили ${expenses.toStringAsFixed(0)} ₽ '
              'при бюджете ${budget.monthlyAmount.toStringAsFixed(0)} ₽.\n'
              'Превышение: ${overspent.toStringAsFixed(0)} ₽ '
              '(+${((overspent / budget.monthlyAmount) * 100).toStringAsFixed(0)}%)',
          category: 'Общее',
          icon: Icons.warning,
          color: Colors.red,
        ));
      }
    }

    // 2. Неактивные категории (подписки без трат >30 дней)
    final subscriptionCategory = categoriesBox.values.firstWhere(
      (cat) => cat.name == 'Подписки',
      orElse: () => Category(
        id: -1,
        name: 'Подписки',
        color: '#9C27B0',
        isDefault: true,
        type: 'expense',
      ),
    );

    if (subscriptionCategory.id != -1) {
      final subscriptionTransactions = recentTransactions
          .where((tx) => tx.categoryId == subscriptionCategory.id)
          .toList();

      if (subscriptionTransactions.isEmpty) {
        recommendations.add(Recommendation(
          type: RecommendationType.inactiveCategory,
          title: '📊 Неактивные подписки?',
          description: 'В категории "Подписки" нет трат за последние 30 дней.\n'
              'Возможно, у вас есть неиспользуемые подписки (Netflix, Spotify и т.д.).\n'
              'Отмена сэкономит деньги.',
          category: 'Подписки',
          icon: Icons.subscriptions_outlined,
          color: Colors.orange,
        ));
      }
    }

    // 3. Частые малые покупки (кофе, такси)
    final frequentCategoriesAnalysis =
        _analyzeFrequentSmallPurchases(recentTransactions, categoriesBox);

    for (var analysis in frequentCategoriesAnalysis) {
      recommendations.add(analysis);
    }

    // 4. Самые дорогие категории
    final expensiveCategoriesAnalysis =
        _analyzeMostExpensiveCategories(recentTransactions, categoriesBox);

    for (var analysis in expensiveCategoriesAnalysis.take(2)) {
      // Топ-2
      recommendations.add(analysis);
    }

    return recommendations;
  }

  /// Анализ частых малых покупок
  static List<Recommendation> _analyzeFrequentSmallPurchases(
    List<Transaction> transactions,
    Box<Category> categoriesBox,
  ) {
    final recommendations = <Recommendation>[];

    // Группируем по категориям
    final categoryGroups = <int, List<Transaction>>{};
    for (var tx in transactions) {
      if (tx.amount >= 0) continue; // Только расходы
      categoryGroups.putIfAbsent(tx.categoryId, () => []).add(tx);
    }

    // Ищем категории с частыми покупками (<1000₽, >5 раз в месяц)
    for (var entry in categoryGroups.entries) {
      final categoryId = entry.key;
      final txs = entry.value;

      // Фильтруем малые покупки
      final smallTxs = txs.where((tx) => tx.amount.abs() < 1000).toList();

      if (smallTxs.length > 5) {
        final totalSpent = smallTxs.fold<double>(0, (sum, tx) => sum + tx.amount.abs());
        final avgAmount = totalSpent / smallTxs.length;
        final potentialSavings = totalSpent * 0.5; // 50% экономия

        final category = categoriesBox.get(categoryId);
        if (category == null) continue;

        recommendations.add(Recommendation(
          type: RecommendationType.frequentSmall,
          title: '💰 Частые покупки: ${category.name}',
          description: 'Вы совершили ${smallTxs.length} покупок в категории "${category.name}"\n'
              'Общая сумма: ${totalSpent.toStringAsFixed(0)} ₽\n'
              'Средняя покупка: ${avgAmount.toStringAsFixed(0)} ₽\n\n'
              'Совет: Сократив частоту на 50%, сэкономите ~${potentialSavings.toStringAsFixed(0)} ₽/месяц',
          savingsAmount: potentialSavings,
          category: category.name,
          icon: Icons.shopping_bag_outlined,
          color: Colors.blue,
        ));
      }
    }

    return recommendations;
  }

  /// Анализ самых дорогих категорий
  static List<Recommendation> _analyzeMostExpensiveCategories(
    List<Transaction> transactions,
    Box<Category> categoriesBox,
  ) {
    final recommendations = <Recommendation>[];

    // Группируем по категориям и считаем траты
    final categoryExpenses = <int, double>{};
    for (var tx in transactions) {
      if (tx.amount >= 0) continue; // Только расходы
      categoryExpenses.update(
        tx.categoryId,
        (value) => value + tx.amount.abs(),
        ifAbsent: () => tx.amount.abs(),
      );
    }

    // Сортируем по сумме
    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Топ-3 самые дорогие категории
    for (var entry in sortedCategories.take(3)) {
      final categoryId = entry.key;
      final totalSpent = entry.value;
      final category = categoriesBox.get(categoryId);
      if (category == null) continue;

      // Пропускаем категории с суммой <5000₽
      if (totalSpent < 5000) continue;

      final potentialSavings = totalSpent * 0.2; // 20% экономия

      recommendations.add(Recommendation(
        type: RecommendationType.expensiveCategory,
        title: '🎯 Оптимизация: ${category.name}',
        description: 'Категория "${category.name}" - одна из самых дорогих\n'
            'Потрачено: ${totalSpent.toStringAsFixed(0)} ₽ за 30 дней\n\n'
            'Совет: Сократив расходы на 20%, сэкономите ~${potentialSavings.toStringAsFixed(0)} ₽/месяц',
        savingsAmount: potentialSavings,
        category: category.name,
        icon: Icons.trending_down,
        color: Colors.green,
      ));
    }

    return recommendations;
  }
}
