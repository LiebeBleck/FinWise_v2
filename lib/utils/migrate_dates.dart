/// Миграция данных: обнуление времени у существующих транзакций
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// Версия миграции данных
const int _currentDataVersion = 2; // v2 = date-only format

/// Проверяет и выполняет необходимые миграции данных
Future<void> checkAndMigrate() async {
  final prefs = await SharedPreferences.getInstance();
  final savedVersion = prefs.getInt('data_version') ?? 1;

  if (savedVersion < _currentDataVersion) {
    print('🔄 Запуск миграции данных: v$savedVersion → v$_currentDataVersion');

    if (savedVersion < 2) {
      await _migrateToDateOnly();
    }

    // Сохранить новую версию
    await prefs.setInt('data_version', _currentDataVersion);
    print('✅ Миграция завершена');
  }
}

/// Миграция v1 → v2: Обнуление времени у всех транзакций
Future<void> _migrateToDateOnly() async {
  print('  → Миграция: обнуление времени транзакций');

  try {
    final box = await Hive.openBox<Transaction>('transactions');
    int migratedCount = 0;

    for (var i = 0; i < box.length; i++) {
      final tx = box.getAt(i);
      if (tx != null) {
        // Проверяем, есть ли время (не 00:00:00)
        if (tx.date.hour != 0 || tx.date.minute != 0 || tx.date.second != 0) {
          // Обнуляем время
          final newDate = DateTime(tx.date.year, tx.date.month, tx.date.day);

          // Создаем новую транзакцию с обновленной датой
          final updatedTx = Transaction(
            id: tx.id,
            amount: tx.amount,
            categoryId: tx.categoryId,
            date: newDate,
            description: tx.description,
            receiptData: tx.receiptData,
          );

          // Сохраняем обратно в box
          await box.putAt(i, updatedTx);
          migratedCount++;
        }
      }
    }

    print('  ✅ Обновлено транзакций: $migratedCount из ${box.length}');
  } catch (e) {
    print('  ❌ Ошибка миграции: $e');
    rethrow;
  }
}

/// Ручной запуск миграции (для тестирования)
Future<void> forceMigrateDateOnly() async {
  print('🔧 Принудительная миграция дат...');
  await _migrateToDateOnly();
  print('✅ Готово');
}
