import 'package:hive/hive.dart';
import '../models/transaction.dart';

class CategoryForecast {
  final int categoryId;
  final double predicted;
  CategoryForecast({required this.categoryId, required this.predicted});
}

class ForecastResult {
  final DateTime targetMonth;
  final double predictedTotal;
  final double lowerBound;
  final double upperBound;
  final List<CategoryForecast> topCategories;
  final int monthsOfData;

  ForecastResult({
    required this.targetMonth,
    required this.predictedTotal,
    required this.lowerBound,
    required this.upperBound,
    required this.topCategories,
    required this.monthsOfData,
  });
}

class ForecastService {
  /// Прогноз расходов на следующий месяц.
  /// Использует взвешенную линейную регрессию по данным за последние 6 месяцев.
  /// Более свежие месяцы имеют больший вес.
  /// Возвращает null если менее 2 месяцев с данными.
  static ForecastResult? forecastNextMonth() {
    final txBox = Hive.box<Transaction>('transactions');
    final now = DateTime.now();

    // Последние 6 месяцев (от старого к новому)
    final months = List.generate(6, (i) {
      int m = now.month - (5 - i);
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      return DateTime(y, m);
    });

    // Суммы расходов по месяцам и категориям
    final monthTotals = <double>[];
    final categoryMonthTotals = <int, List<double>>{};

    for (int idx = 0; idx < months.length; idx++) {
      final month = months[idx];
      final monthTx = txBox.values
          .where((t) =>
              t.isCompleted &&
              t.isExpense &&
              t.date.year == month.year &&
              t.date.month == month.month)
          .toList();

      monthTotals.add(monthTx.fold(0.0, (s, t) => s + t.absoluteAmount));

      for (final t in monthTx) {
        categoryMonthTotals.putIfAbsent(
            t.categoryId, () => List.filled(6, 0.0));
        categoryMonthTotals[t.categoryId]![idx] += t.absoluteAmount;
      }
    }

    final nonZeroCount = monthTotals.where((v) => v > 0).length;
    if (nonZeroCount < 2) return null;

    final predictedTotal =
        _weightedLinearRegression(monthTotals).clamp(0.0, double.infinity);

    // Прогноз по категориям
    final categoryPredictions = <int, double>{};
    for (final entry in categoryMonthTotals.entries) {
      final predicted =
          _weightedLinearRegression(entry.value).clamp(0.0, double.infinity);
      if (predicted > 0) categoryPredictions[entry.key] = predicted;
    }

    final sortedCategories = categoryPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories
        .take(5)
        .map((e) =>
            CategoryForecast(categoryId: e.key, predicted: e.value))
        .toList();

    int nextMonth = now.month + 1;
    int nextYear = now.year;
    if (nextMonth > 12) {
      nextMonth -= 12;
      nextYear++;
    }

    return ForecastResult(
      targetMonth: DateTime(nextYear, nextMonth),
      predictedTotal: predictedTotal,
      lowerBound: predictedTotal * 0.82,
      upperBound: predictedTotal * 1.22,
      topCategories: topCategories,
      monthsOfData: nonZeroCount,
    );
  }

  /// Взвешенная линейная регрессия.
  /// Веса: 1, 2, ..., n (свежие данные имеют больший вес).
  /// Возвращает прогноз для индекса n (следующая точка).
  static double _weightedLinearRegression(List<double> values) {
    final n = values.length;
    if (n == 0) return 0;
    if (n == 1) return values[0];

    double sumW = 0, sumWX = 0, sumWY = 0, sumWX2 = 0, sumWXY = 0;
    for (int i = 0; i < n; i++) {
      final w = (i + 1).toDouble();
      final x = i.toDouble();
      final y = values[i];
      sumW += w;
      sumWX += w * x;
      sumWY += w * y;
      sumWX2 += w * x * x;
      sumWXY += w * x * y;
    }

    final denom = sumW * sumWX2 - sumWX * sumWX;
    if (denom.abs() < 1e-10) return sumWY / sumW; // константа

    final slope = (sumW * sumWXY - sumWX * sumWY) / denom;
    final intercept = (sumWY - slope * sumWX) / sumW;

    return intercept + slope * n;
  }
}
