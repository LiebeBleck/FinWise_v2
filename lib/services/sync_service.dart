import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_queue_item.dart';

/// Сервис синхронизации для офлайн режима
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  final Connectivity _connectivity = Connectivity();

  /// Запустить фоновую синхронизацию
  void startBackgroundSync() {
    // Проверка каждые 30 секунд
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isSyncing) {
        await processSyncQueue();
      }
    });

    // Также запускать при изменении подключения
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        processSyncQueue();
      }
    });
  }

  /// Остановить фоновую синхронизацию
  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Проверка подключения к интернету
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Добавить элемент в очередь синхронизации
  Future<void> addToQueue({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final box = Hive.box<SyncQueueItem>('sync_queue');

    final item = SyncQueueItem(
      id: const Uuid().v4(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    await box.add(item);
  }

  /// Обработать очередь синхронизации
  Future<void> processSyncQueue() async {
    if (_isSyncing) return;
    if (!await hasConnection()) return;

    _isSyncing = true;

    try {
      final box = Hive.box<SyncQueueItem>('sync_queue');
      final items = box.values.where((item) => item.canRetryNow).toList();

      for (var item in items) {
        try {
          await _processItem(item);

          // Успешно - удаляем из очереди
          await item.delete();
        } catch (e) {
          // Ошибка - увеличиваем счётчик retry
          item.retryCount++;
          item.lastAttempt = DateTime.now();

          if (!item.shouldRetry) {
            // После 5 попыток - удаляем
            await item.delete();
          } else {
            await item.save();
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Обработать отдельный элемент очереди
  Future<void> _processItem(SyncQueueItem item) async {
    switch (item.type) {
      case 'ml_categorize':
        // TODO: отправить запрос к ML API
        break;
      case 'qr_receipt_details':
        // TODO: получить детали чека через API ФНС
        break;
      default:
        // Неизвестный тип - удаляем
        break;
    }
  }

  /// Получить количество элементов в очереди
  int get queueLength {
    final box = Hive.box<SyncQueueItem>('sync_queue');
    return box.length;
  }

  /// Получить статус синхронизации
  bool get isSyncing => _isSyncing;
}
