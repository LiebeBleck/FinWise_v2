import 'package:hive/hive.dart';

part 'savings_goal.g.dart';

@HiveType(typeId: 5)
class SavingsGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double targetAmount;

  @HiveField(3)
  double savedAmount;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? deadline;

  @HiveField(6)
  String? icon;

  @HiveField(7)
  String? color;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    required this.createdAt,
    this.deadline,
    this.icon,
    this.color,
  });

  /// Прогресс: 0.0 – 1.0
  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Цель достигнута
  bool get isCompleted => savedAmount >= targetAmount;

  /// Сколько откладывать в месяц для достижения цели к дедлайну
  double? get monthlySavingsNeeded {
    if (deadline == null) return null;
    final remaining = targetAmount - savedAmount;
    if (remaining <= 0) return 0;
    final now = DateTime.now();
    final months = (deadline!.year - now.year) * 12 + (deadline!.month - now.month);
    if (months <= 0) return remaining;
    return remaining / months;
  }
}
