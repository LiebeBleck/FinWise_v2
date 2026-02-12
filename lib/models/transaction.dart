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

  // === Планируемые траты (v1.1) ===
  @HiveField(6)
  bool isPlanned; // true = планируемая, false = выполненная

  @HiveField(7)
  DateTime? plannedDate; // Запланированная дата (для будущих трат)

  @HiveField(8)
  bool isRecurring; // true = повторяющаяся трата

  @HiveField(9)
  String? recurrenceRule; // "daily", "weekly", "monthly", "yearly"

  @HiveField(10)
  DateTime? nextRecurrenceDate; // Дата следующего повторения

  Transaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required DateTime date,
    required this.description,
    this.receiptData,
    this.isPlanned = false, // По умолчанию - выполненная трата
    this.plannedDate,
    this.isRecurring = false,
    this.recurrenceRule,
    this.nextRecurrenceDate,
  }) : date = DateTime(date.year, date.month, date.day); // Обнуляем время!

  // Проверка, является ли транзакция доходом
  bool get isIncome => amount > 0;

  // Проверка, является ли транзакция расходом
  bool get isExpense => amount < 0;

  // Абсолютное значение суммы (для отображения)
  double get absoluteAmount => amount.abs();

  // === Планируемые траты - геттеры ===

  // Проверка, является ли трата выполненной
  bool get isCompleted => !isPlanned;

  // Проверка, просрочена ли планируемая трата
  bool get isOverdue {
    if (!isPlanned || plannedDate == null) return false;
    return plannedDate!.isBefore(DateTime.now());
  }

  // Проверка, нужно ли скоро выполнить (в ближайшие 3 дня)
  bool get isDueSoon {
    if (!isPlanned || plannedDate == null) return false;
    final today = DateTime.now();
    final daysUntil = plannedDate!.difference(today).inDays;
    return daysUntil >= 0 && daysUntil <= 3;
  }

  // Получить текст правила повторения на русском
  String get recurrenceRuleDisplay {
    if (!isRecurring || recurrenceRule == null) return '';
    switch (recurrenceRule) {
      case 'daily':
        return 'Ежедневно';
      case 'weekly':
        return 'Еженедельно';
      case 'monthly':
        return 'Ежемесячно';
      case 'yearly':
        return 'Ежегодно';
      default:
        return '';
    }
  }
}
