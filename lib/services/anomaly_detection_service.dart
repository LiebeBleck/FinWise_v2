import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';

/// Результат проверки аномалии
class AnomalyResult {
  final bool isAnomaly;
  final double amount;
  final double mean;
  final double stdDev;
  final String categoryName;

  const AnomalyResult({
    required this.isAnomaly,
    required this.amount,
    required this.mean,
    required this.stdDev,
    required this.categoryName,
  });
}

/// Сервис обнаружения аномальных трат (z-score, офлайн, Hive).
///
/// Аномалия = расход > mean + 2σ по категории за последние 90 дней.
/// Требует минимум 5 транзакций в истории для вывода предупреждения.
class AnomalyDetectionService {
  static const int _minSamples = 5;
  static const double _zThreshold = 2.0;
  static const int _lookbackDays = 90;

  /// Проверяет, является ли сумма [amount] аномальной для категории [categoryId].
  /// Возвращает null, если данных недостаточно для анализа.
  static AnomalyResult? check({
    required double amount,
    required int categoryId,
    required String categoryName,
  }) {
    final txBox = Hive.box<Transaction>('transactions');
    final cutoff = DateTime.now().subtract(const Duration(days: _lookbackDays));

    final history = txBox.values
        .where((t) =>
            t.isCompleted &&
            t.isExpense &&
            t.categoryId == categoryId &&
            t.date.isAfter(cutoff))
        .map((t) => t.absoluteAmount)
        .toList();

    if (history.length < _minSamples) return null;

    final mean = history.reduce((a, b) => a + b) / history.length;

    final variance =
        history.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
            history.length;
    final stdDev = sqrt(variance);

    // Если все суммы одинаковые — нет дисперсии, аномалию не определить
    if (stdDev < 0.01) return null;

    final zScore = (amount - mean) / stdDev;

    return AnomalyResult(
      isAnomaly: zScore > _zThreshold,
      amount: amount,
      mean: mean,
      stdDev: stdDev,
      categoryName: categoryName,
    );
  }
}
