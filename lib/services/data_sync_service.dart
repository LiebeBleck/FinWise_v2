import 'package:hive/hive.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'api_service.dart';

/// Статус последней синхронизации
enum SyncStatus { idle, syncing, success, error }

/// Двусторонняя синхронизация данных с backend.
///
/// Push: Hive → сервер (после каждого изменения или вручную).
/// Pull: сервер → Hive (при первом входе / восстановлении на новом устройстве).
class DataSyncService {
  static SyncStatus _status = SyncStatus.idle;
  static String? _lastError;
  static DateTime? _lastSyncAt;

  static SyncStatus get status => _status;
  static String? get lastError => _lastError;
  static DateTime? get lastSyncAt => _lastSyncAt;

  // ── Push ─────────────────────────────────────────────────

  /// Отправить все данные из Hive на сервер.
  static Future<bool> pushAll() async {
    if (_status == SyncStatus.syncing) return false;
    if (!await ApiService.hasToken()) return false;

    _status = SyncStatus.syncing;
    try {
      final payload = _buildPushPayload();
      await ApiService.pushData(payload);
      _status = SyncStatus.success;
      _lastSyncAt = DateTime.now();
      _lastError = null;
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  /// Push в фоне (fire-and-forget).
  static void pushAllBackground() {
    pushAll();
  }

  // ── Pull ─────────────────────────────────────────────────

  /// Загрузить данные с сервера → Hive. Сервер побеждает.
  static Future<bool> pullAll() async {
    if (!await ApiService.hasToken()) return false;

    _status = SyncStatus.syncing;
    try {
      final data = await ApiService.pullData();
      await _applyPullData(data);
      _status = SyncStatus.success;
      _lastSyncAt = DateTime.now();
      _lastError = null;
      return true;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  // ── Build push payload ────────────────────────────────────

  static Map<String, dynamic> _buildPushPayload() {
    final txBox = Hive.box<Transaction>('transactions');
    final budgetBox = Hive.box<Budget>('budget');
    final catBox = Hive.box<Category>('categories');

    // All transactions (completed + planned)
    final transactions = txBox.values
        .map((t) => {
              'local_id': t.id, // UUID string
              'amount': t.amount,
              'category_id': t.categoryId,
              'description': t.description,
              'date': t.date.toIso8601String(),
              'is_planned': t.isPlanned,
              'planned_date': t.plannedDate?.toIso8601String(),
              'is_recurring': t.isRecurring,
              'recurrence_rule': t.recurrenceRule,
              'next_recurrence_date': t.nextRecurrenceDate?.toIso8601String(),
              'receipt_data': t.receiptData,
            })
        .toList();

    // Budget
    final budget = budgetBox.get('current');
    Map<String, dynamic>? budgetPayload;
    if (budget != null) {
      budgetPayload = {
        'monthly_amount': budget.monthlyAmount,
        'period_start': budget.periodStart.toIso8601String(),
        'period_type': budget.effectivePeriodType,
        'category_budgets': budget.typedCategoryBudgets.isNotEmpty
            ? budget.typedCategoryBudgets
                .map((k, v) => MapEntry(k.toString(), v))
            : null,
      };
    }

    // Custom categories (non-default)
    final customCats = catBox.values
        .where((c) => !c.isDefault)
        .map((c) => {
              'local_id': c.id,
              'name': c.name,
              'color': c.color,
              'type': c.type,
              'is_default': false,
            })
        .toList();

    return {
      'transactions': transactions,
      'budget': budgetPayload,
      'custom_categories': customCats,
    };
  }

  // ── Apply pull data ───────────────────────────────────────

  static Future<void> _applyPullData(Map<String, dynamic> data) async {
    final txBox = Hive.box<Transaction>('transactions');
    final budgetBox = Hive.box<Budget>('budget');
    final catBox = Hive.box<Category>('categories');

    // ── Transactions: merge by local_id (UUID string) ────
    final serverTxs =
        (data['transactions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final serverIds = <String>{};

    for (final tx in serverTxs) {
      final localId = tx['local_id'] as String? ?? '';
      if (localId.isEmpty) continue;
      serverIds.add(localId);

      final amount = (tx['amount'] as num).toDouble();
      final categoryId = tx['category_id'] as int? ?? 19;
      final description = tx['description'] as String? ?? '';
      final date = DateTime.parse(tx['date'] as String);
      final isPlanned = tx['is_planned'] as bool? ?? false;
      final isRecurring = tx['is_recurring'] as bool? ?? false;
      final recurrenceRule = tx['recurrence_rule'] as String?;
      final plannedDate = tx['planned_date'] != null
          ? DateTime.parse(tx['planned_date'] as String)
          : null;
      final nextRec = tx['next_recurrence_date'] != null
          ? DateTime.parse(tx['next_recurrence_date'] as String)
          : null;
      final receiptData = tx['receipt_data'] as Map<String, dynamic>?;

      if (txBox.containsKey(localId)) {
        // Update existing
        final existing = txBox.get(localId)!;
        existing.amount = amount;
        existing.categoryId = categoryId;
        existing.description = description;
        existing.date = date;
        existing.isPlanned = isPlanned;
        existing.plannedDate = plannedDate;
        existing.isRecurring = isRecurring;
        existing.recurrenceRule = recurrenceRule;
        existing.nextRecurrenceDate = nextRec;
        if (receiptData != null) existing.receiptData = receiptData;
        await existing.save();
      } else {
        // New transaction from server
        final newTx = Transaction(
          id: localId,
          amount: amount,
          categoryId: categoryId,
          date: date,
          description: description,
          isPlanned: isPlanned,
          plannedDate: plannedDate,
          isRecurring: isRecurring,
          recurrenceRule: recurrenceRule,
          nextRecurrenceDate: nextRec,
          receiptData: receiptData,
        );
        await txBox.put(localId, newTx);
      }
    }

    // Remove local transactions not on server (only if server sent data)
    if (serverTxs.isNotEmpty) {
      final toDelete = txBox.keys
          .where((k) => !serverIds.contains(k))
          .toList();
      for (final key in toDelete) {
        await txBox.delete(key);
      }
    }

    // ── Budget ────────────────────────────────────────────
    final budgetData = data['budget'] as Map<String, dynamic>?;
    if (budgetData != null) {
      final newAmount = (budgetData['monthly_amount'] as num).toDouble();
      final newStart = DateTime.parse(budgetData['period_start'] as String);
      final newType = budgetData['period_type'] as String? ?? 'monthly';
      final existing = budgetBox.get('current');
      if (existing != null) {
        existing.monthlyAmount = newAmount;
        existing.periodStart = newStart;
        existing.periodType = newType;
        await existing.save();
      } else {
        final b = Budget(monthlyAmount: newAmount, periodStart: newStart);
        b.periodType = newType;
        await budgetBox.put('current', b);
      }
    }

    // ── Custom categories ─────────────────────────────────
    final serverCats = (data['custom_categories'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final serverCatIds =
        serverCats.map((c) => c['local_id'] as int? ?? -1).toSet();

    for (final c in serverCats) {
      final localId = c['local_id'] as int? ?? -1;
      if (localId < 0) continue;
      if (!catBox.containsKey(localId)) {
        final cat = Category(
          id: localId,
          name: c['name'] as String,
          color: c['color'] as String,
          type: c['type'] as String? ?? 'expense',
          isDefault: false,
        );
        await catBox.put(localId, cat);
      }
    }

    // Remove custom categories not on server
    if (serverCats.isNotEmpty) {
      final toDeleteCats = catBox.values
          .where((c) => !c.isDefault && !serverCatIds.contains(c.id))
          .map((c) => c.id)
          .toList();
      for (final id in toDeleteCats) {
        await catBox.delete(id);
      }
    }
  }
}
