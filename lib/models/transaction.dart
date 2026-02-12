import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  String id; // UUID

  @HiveField(1)
  double amount; // Положительное = доход, отрицательное = расход

  @HiveField(2)
  int categoryId;

  @HiveField(3)
  DateTime date; // Всегда с временем 00:00:00

  @HiveField(4)
  String description;

  @HiveField(5)
  Map<String, dynamic>? receiptData; // Данные чека (опционально)

  Transaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required DateTime date,
    required this.description,
    this.receiptData,
  }) : date = DateTime(date.year, date.month, date.day); // Обнуляем время!

  // Проверка, является ли транзакция доходом
  bool get isIncome => amount > 0;

  // Проверка, является ли транзакция расходом
  bool get isExpense => amount < 0;

  // Абсолютное значение суммы (для отображения)
  double get absoluteAmount => amount.abs();
}
