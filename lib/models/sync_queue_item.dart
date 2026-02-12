import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 4)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  String id; // UUID

  @HiveField(1)
  String type; // 'ml_categorize', 'qr_receipt_details', etc.

  @HiveField(2)
  Map<String, dynamic> data; // Данные для синхронизации

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  int retryCount; // Количество попыток

  @HiveField(5)
  DateTime? lastAttempt; // Последняя попытка

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttempt,
  });

  /// Проверка, нужно ли повторить попытку
  bool get shouldRetry => retryCount < 5;

  /// Время до следующей попытки (экспоненциальная задержка)
  Duration get retryDelay {
    if (lastAttempt == null) return Duration.zero;

    // Экспоненциальная задержка: 1, 2, 4, 8, 16 минут
    final delayMinutes = 1 << retryCount.clamp(0, 4);
    return Duration(minutes: delayMinutes);
  }

  /// Можно ли попробовать сейчас
  bool get canRetryNow {
    if (lastAttempt == null) return true;
    return DateTime.now().difference(lastAttempt!) >= retryDelay;
  }
}
