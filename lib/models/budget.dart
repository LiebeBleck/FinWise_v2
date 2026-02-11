import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 3)
class Budget extends HiveObject {
  @HiveField(0)
  double monthlyAmount;

  @HiveField(1)
  DateTime periodStart;

  Budget({
    required this.monthlyAmount,
    required this.periodStart,
  });

  // Проверка, является ли бюджет активным в текущем месяце
  bool get isCurrentMonth {
    final now = DateTime.now();
    return periodStart.year == now.year && periodStart.month == now.month;
  }

  // Получить конец периода бюджета
  DateTime get periodEnd {
    return DateTime(periodStart.year, periodStart.month + 1, 0);
  }
}
