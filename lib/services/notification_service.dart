import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/transaction.dart';
import '../models/budget.dart';
import 'anomaly_detection_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int _budgetWarning90Id = 1001;
  static const int _budgetWarning100Id = 1002;
  static const int _weeklyReportId = 1003;
  static const int _plannedBaseId = 2000; // + transactionId
  static const int _anomalyId = 3000;

  // Channel IDs
  static const String _budgetChannelId = 'finwise_budget';
  static const String _remindersChannelId = 'finwise_reminders';
  static const String _weeklyChannelId = 'finwise_weekly';
  static const String _anomalyChannelId = 'finwise_anomaly';

  /// Инициализация сервиса уведомлений
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Moscow'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Request Android 13+ permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Budget warnings ────────────────────────────────────

  /// Проверяет бюджет и показывает уведомление если нужно
  static Future<void> checkBudgetAndNotify() async {
    final budgetBox = Hive.box<Budget>('budget');
    final budget = budgetBox.get('current');
    if (budget == null || budget.monthlyAmount <= 0) return;

    final txBox = Hive.box<Transaction>('transactions');
    final now = DateTime.now();
    final monthlyExpenses = txBox.values
        .where((t) =>
            t.isCompleted &&
            t.isExpense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);

    final ratio = monthlyExpenses / budget.monthlyAmount;

    if (ratio >= 1.0) {
      await _showBudgetNotification(
        id: _budgetWarning100Id,
        title: '🚨 Бюджет исчерпан!',
        body:
            'Расходы превысили месячный бюджет. '
            'Потрачено: ${_fmt(monthlyExpenses)} из ${_fmt(budget.monthlyAmount)}',
      );
    } else if (ratio >= 0.9) {
      await _showBudgetNotification(
        id: _budgetWarning90Id,
        title: '⚠️ Бюджет почти исчерпан',
        body:
            'Использовано ${(ratio * 100).toStringAsFixed(0)}% месячного бюджета. '
            'Осталось: ${_fmt(budget.monthlyAmount - monthlyExpenses)}',
      );
    }
  }

  static Future<void> _showBudgetNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _budgetChannelId,
          'Бюджет',
          channelDescription: 'Предупреждения о превышении бюджета',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Planned transactions reminders ────────────────────

  /// Планирует напоминание за 1 день до плановой транзакции
  static Future<void> schedulePlannedReminders() async {
    final txBox = Hive.box<Transaction>('transactions');
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final planned = txBox.values.where((t) =>
        t.isPlanned &&
        t.plannedDate != null &&
        t.plannedDate!.year == tomorrow.year &&
        t.plannedDate!.month == tomorrow.month &&
        t.plannedDate!.day == tomorrow.day);

    for (final t in planned) {
      // Use hashCode of UUID string to get a stable int ID
      final notifId = (_plannedBaseId + t.id.hashCode).abs() & 0x7FFFFFFF;
      // Schedule for 9:00 the day before
      final scheduleDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        9,
        0,
      );

      if (scheduleDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      await _plugin.zonedSchedule(
        notifId,
        '📅 Запланированный платёж завтра',
        '${t.description.isNotEmpty ? t.description : "Транзакция"}: '
            '${_fmt(t.absoluteAmount)}',
        scheduleDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _remindersChannelId,
            'Напоминания',
            channelDescription: 'Напоминания о плановых транзакциях',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── Weekly report ──────────────────────────────────────

  /// Планирует еженедельный отчёт в понедельник 9:00
  static Future<void> scheduleWeeklyReport() async {
    // Cancel previous
    await _plugin.cancel(_weeklyReportId);

    final now = tz.TZDateTime.now(tz.local);
    // Find next Monday
    var nextMonday = now;
    while (nextMonday.weekday != DateTime.monday) {
      nextMonday = nextMonday.add(const Duration(days: 1));
    }
    final scheduleDate = tz.TZDateTime(
      tz.local,
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      9,
      0,
    );

    // Build quick stats
    final txBox = Hive.box<Transaction>('transactions');
    final weekStart = now.subtract(const Duration(days: 7));
    final weekTx = txBox.values.where((t) =>
        t.isCompleted && t.date.isAfter(weekStart.toLocal()));
    final income = weekTx
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.absoluteAmount);
    final expense = weekTx
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.absoluteAmount);

    await _plugin.zonedSchedule(
      _weeklyReportId,
      '📊 Итоги недели — FinWise',
      'Доходы: ${_fmt(income)} · Расходы: ${_fmt(expense)} · '
          'Баланс: ${_fmt(income - expense)}',
      scheduleDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklyChannelId,
          'Еженедельный отчёт',
          channelDescription: 'Еженедельная сводка по финансам',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── Anomaly notification ───────────────────────────────

  /// Push-уведомление об аномальной трате
  static Future<void> showAnomalyNotification(AnomalyResult result) async {
    await _plugin.show(
      _anomalyId,
      '⚠️ Необычная трата!',
      'Расход ${_fmt(result.amount)} в "${result.categoryName}" '
          'значительно выше среднего (${_fmt(result.mean)})',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _anomalyChannelId,
          'Аномальные траты',
          channelDescription: 'Предупреждения о необычно крупных расходах',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Отменить все уведомления
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helper ─────────────────────────────────────────────

  static String _fmt(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} млн ₽';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}к ₽';
    }
    return '${amount.toStringAsFixed(0)} ₽';
  }
}
