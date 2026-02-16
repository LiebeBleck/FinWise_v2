import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';

/// Сервис для экспорта и импорта данных в JSON
class ExportImportService {
  /// Экспорт всех данных в JSON файл
  static Future<ExportResult> exportToJSON() async {
    try {
      // Получаем данные из Hive
      final transactionsBox = await Hive.openBox<Transaction>('transactions');
      final categoriesBox = await Hive.openBox<Category>('categories');
      final budgetsBox = await Hive.openBox<Budget>('budgets');

      // Формируем JSON структуру
      final data = {
        'version': '1.0',
        'export_date': DateTime.now().toIso8601String(),
        'transactions': transactionsBox.values
            .map((tx) => {
                  'id': tx.id,
                  'amount': tx.amount,
                  'categoryId': tx.categoryId,
                  'date': tx.date.toIso8601String(),
                  'description': tx.description,
                  'receiptData': tx.receiptData,
                  'isPlanned': tx.isPlanned,
                  'plannedDate': tx.plannedDate?.toIso8601String(),
                  'isRecurring': tx.isRecurring,
                  'recurrenceRule': tx.recurrenceRule,
                  'nextRecurrenceDate': tx.nextRecurrenceDate?.toIso8601String(),
                })
            .toList(),
        'categories': categoriesBox.values
            .map((cat) => {
                  'id': cat.id,
                  'name': cat.name,
                  'color': cat.color,
                  'isDefault': cat.isDefault,
                  'type': cat.type,
                })
            .toList(),
        'budgets': budgetsBox.values
            .map((budget) => {
                  'monthlyAmount': budget.monthlyAmount,
                  'periodStart': budget.periodStart.toIso8601String(),
                })
            .toList(),
      };

      // Конвертируем в JSON строку
      final jsonString = JsonEncoder.withIndent('  ').convert(data);

      // Получаем директорию для сохранения
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'finwise_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');

      // Сохраняем файл
      await file.writeAsString(jsonString);

      return ExportResult(
        success: true,
        filePath: file.path,
        transactionsCount: transactionsBox.length,
        categoriesCount: categoriesBox.length,
        budgetsCount: budgetsBox.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Импорт данных из JSON файла
  static Future<ImportResult> importFromJSON() async {
    try {
      // Выбираем файл
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: false,
          error: 'Файл не выбран',
        );
      }

      // Читаем файл
      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Валидация версии
      if (data['version'] != '1.0') {
        return ImportResult(
          success: false,
          error: 'Неподдерживаемая версия файла: ${data['version']}',
        );
      }

      // Открываем Hive boxes
      final transactionsBox = await Hive.openBox<Transaction>('transactions');
      final categoriesBox = await Hive.openBox<Category>('categories');
      final budgetsBox = await Hive.openBox<Budget>('budgets');

      int transactionsImported = 0;
      int categoriesImported = 0;
      int budgetsImported = 0;

      // Импортируем транзакции
      if (data.containsKey('transactions')) {
        final transactions = data['transactions'] as List;
        for (var txData in transactions) {
          final tx = Transaction(
            id: txData['id'],
            amount: txData['amount'].toDouble(),
            categoryId: txData['categoryId'],
            date: DateTime.parse(txData['date']),
            description: txData['description'],
            receiptData: txData['receiptData'] != null
                ? Map<String, dynamic>.from(txData['receiptData'])
                : null,
            isPlanned: txData['isPlanned'] ?? false,
            plannedDate: txData['plannedDate'] != null
                ? DateTime.parse(txData['plannedDate'])
                : null,
            isRecurring: txData['isRecurring'] ?? false,
            recurrenceRule: txData['recurrenceRule'],
            nextRecurrenceDate: txData['nextRecurrenceDate'] != null
                ? DateTime.parse(txData['nextRecurrenceDate'])
                : null,
          );

          // Проверяем, существует ли транзакция
          if (!transactionsBox.containsKey(tx.id)) {
            await transactionsBox.put(tx.id, tx);
            transactionsImported++;
          }
        }
      }

      // Импортируем категории (только пользовательские)
      if (data.containsKey('categories')) {
        final categories = data['categories'] as List;
        for (var catData in categories) {
          // Пропускаем стандартные категории
          if (catData['isDefault'] == true) continue;

          final cat = Category(
            id: catData['id'],
            name: catData['name'],
            color: catData['color'],
            isDefault: false,
            type: catData['type'] ?? 'expense',
          );

          if (!categoriesBox.containsKey(cat.id)) {
            await categoriesBox.put(cat.id, cat);
            categoriesImported++;
          }
        }
      }

      // Импортируем бюджеты
      if (data.containsKey('budgets')) {
        final budgets = data['budgets'] as List;
        for (var budgetData in budgets) {
          final budget = Budget(
            monthlyAmount: budgetData['monthlyAmount'].toDouble(),
            periodStart: DateTime.parse(budgetData['periodStart']),
          );

          // Добавляем бюджет (Hive автоматически добавляет)
          await budgetsBox.add(budget);
          budgetsImported++;
        }
      }

      return ImportResult(
        success: true,
        transactionsCount: transactionsImported,
        categoriesCount: categoriesImported,
        budgetsCount: budgetsImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}

/// Результат экспорта
class ExportResult {
  final bool success;
  final String? filePath;
  final int transactionsCount;
  final int categoriesCount;
  final int budgetsCount;
  final String? error;

  ExportResult({
    required this.success,
    this.filePath,
    this.transactionsCount = 0,
    this.categoriesCount = 0,
    this.budgetsCount = 0,
    this.error,
  });
}

/// Результат импорта
class ImportResult {
  final bool success;
  final int transactionsCount;
  final int categoriesCount;
  final int budgetsCount;
  final String? error;

  ImportResult({
    required this.success,
    this.transactionsCount = 0,
    this.categoriesCount = 0,
    this.budgetsCount = 0,
    this.error,
  });
}
