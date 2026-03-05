import 'package:hive/hive.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/category.dart';

class CategoryBudgetStatus {
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final double limit;
  final double spent;

  CategoryBudgetStatus({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.limit,
    required this.spent,
  });

  double get ratio => limit > 0 ? (spent / limit).clamp(0.0, double.infinity) : 0.0;
  bool get isOverBudget => spent > limit;
}

class BudgetService {
  static Box<Budget> get _budgetBox => Hive.box<Budget>('budget');
  static Box<Transaction> get _txBox => Hive.box<Transaction>('transactions');
  static Box<Category> get _catBox => Hive.box<Category>('categories');

  /// Получить текущий бюджет
  static Budget? getCurrentBudget() => _budgetBox.get('current');

  /// Вычислить начало текущего периода для типа
  static DateTime calculatePeriodStart(String periodType) {
    final now = DateTime.now();
    switch (periodType) {
      case 'weekly':
        final daysFromMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysFromMonday);
      case 'yearly':
        return DateTime(now.year, 1, 1);
      default: // monthly
        return DateTime(now.year, now.month, 1);
    }
  }

  /// Сумма расходов за период бюджета
  static double getExpensesForPeriod(Budget budget) {
    final start = budget.periodStart;
    final end = budget.periodEnd;
    return _txBox.values
        .where((t) =>
            t.isCompleted &&
            t.isExpense &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);
  }

  /// Сумма расходов по конкретной категории за период
  static double getCategoryExpenses(Budget budget, int categoryId) {
    final start = budget.periodStart;
    final end = budget.periodEnd;
    return _txBox.values
        .where((t) =>
            t.isCompleted &&
            t.isExpense &&
            t.categoryId == categoryId &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);
  }

  /// Статусы бюджетов по категориям
  static List<CategoryBudgetStatus> getCategoryBudgetStatuses(Budget budget) {
    final limits = budget.typedCategoryBudgets;
    if (limits.isEmpty) return [];

    final result = <CategoryBudgetStatus>[];
    for (final entry in limits.entries) {
      final cat = _catBox.get(entry.key);
      if (cat == null) continue;
      final spent = getCategoryExpenses(budget, entry.key);
      result.add(CategoryBudgetStatus(
        categoryId: entry.key,
        categoryName: cat.name,
        categoryColor: cat.color,
        limit: entry.value,
        spent: spent,
      ));
    }
    result.sort((a, b) => b.ratio.compareTo(a.ratio));
    return result;
  }

  /// Человекочитаемое название периода
  static String periodLabel(String periodType) {
    switch (periodType) {
      case 'weekly':
        return 'Недельный';
      case 'yearly':
        return 'Годовой';
      default:
        return 'Месячный';
    }
  }

  /// Обновить период бюджета при смене типа
  static Future<void> updateBudgetPeriod(String periodType) async {
    final budget = getCurrentBudget();
    if (budget == null) return;
    budget.periodType = periodType;
    budget.periodStart = calculatePeriodStart(periodType);
    await budget.save();
  }
}
