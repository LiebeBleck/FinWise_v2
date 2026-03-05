import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 3)
class Budget extends HiveObject {
  @HiveField(0)
  double monthlyAmount;

  @HiveField(1)
  DateTime periodStart;

  @HiveField(2)
  String? periodType; // 'weekly' | 'monthly' | 'yearly'

  @HiveField(3)
  Map<dynamic, dynamic>? categoryBudgets; // categoryId (int) → limit (double)

  Budget({
    required this.monthlyAmount,
    required this.periodStart,
    this.periodType,
    this.categoryBudgets,
  });

  /// Эффективный тип периода (по умолчанию 'monthly')
  String get effectivePeriodType => periodType ?? 'monthly';

  /// Конец периода бюджета
  DateTime get periodEnd {
    switch (effectivePeriodType) {
      case 'weekly':
        return periodStart.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(periodStart.year + 1, periodStart.month, periodStart.day);
      default: // monthly
        return DateTime(periodStart.year, periodStart.month + 1, 0);
    }
  }

  /// Является ли бюджет активным в текущем периоде
  bool get isCurrentPeriod {
    final now = DateTime.now();
    return !now.isBefore(periodStart) && !now.isAfter(periodEnd);
  }

  /// Сумма бюджета по конкретной категории
  double? getCategoryLimit(int categoryId) {
    final v = categoryBudgets?[categoryId];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  /// Получить лимиты категорий в типизированном виде
  Map<int, double> get typedCategoryBudgets {
    if (categoryBudgets == null) return {};
    return Map.fromEntries(
      categoryBudgets!.entries.map(
        (e) => MapEntry(e.key as int, (e.value as num).toDouble()),
      ),
    );
  }

  /// Установить лимит категории
  void setCategoryLimit(int categoryId, double limit) {
    categoryBudgets ??= {};
    categoryBudgets![categoryId] = limit;
  }

  /// Удалить лимит категории
  void removeCategoryLimit(int categoryId) {
    categoryBudgets?.remove(categoryId);
  }

  // Обратная совместимость
  bool get isCurrentMonth {
    final now = DateTime.now();
    return periodStart.year == now.year && periodStart.month == now.month;
  }
}
