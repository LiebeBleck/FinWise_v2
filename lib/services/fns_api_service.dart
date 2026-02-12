import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/receipt.dart';

/// Сервис для работы с API ФНС (получение детальных данных чека)
class FnsApiService {
  // Используем бесплатный сервис проверки чеков
  static const String _baseUrl = 'https://proverkacheka.com/api/v1';

  /// Получить детальные данные чека по QR-коду
  Future<Receipt?> getReceiptDetails(String qrData) async {
    try {
      // Парсим QR-код для получения параметров
      final params = Uri.splitQueryString(qrData);

      // Формируем URL для запроса
      final url = Uri.parse('$_baseUrl/check/get');

      // Отправляем запрос
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          't': params['t'], // дата/время
          's': params['s'], // сумма
          'fn': params['fn'], // фискальный номер
          'i': params['i'], // номер ФД
          'fp': params['fp'], // фискальный признак
          'n': params['n'], // тип операции
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Парсим данные чека
        return _parseReceiptFromApi(data, qrData);
      } else {
        // Ошибка API - возвращаем базовый чек из QR
        return Receipt.fromQR(qrData);
      }
    } catch (e) {
      // При ошибке возвращаем базовый чек из QR
      return Receipt.fromQR(qrData);
    }
  }

  /// Парсинг данных чека из ответа API
  Receipt _parseReceiptFromApi(Map<String, dynamic> data, String qrRaw) {
    // Извлекаем данные чека
    final checkData = data['data']?['json'] ?? {};

    // Общая сумма
    final totalSum = (checkData['totalSum'] ?? 0.0).toDouble() / 100;

    // Дата и время
    DateTime? dateTime;
    if (checkData.containsKey('dateTime')) {
      try {
        dateTime = DateTime.parse(checkData['dateTime']);
      } catch (e) {
        // Игнорируем ошибки парсинга
      }
    }

    // Название магазина
    final retailer = checkData['user'] ?? checkData['retailPlace'];
    final retailerName = retailer is String ? retailer : null;

    // ИНН магазина
    final userInn = checkData['userInn']?.toString();

    // Товары
    final itemsData = checkData['items'] as List<dynamic>? ?? [];
    final items = itemsData.map((item) {
      final name = item['name'] ?? 'Товар';
      final price = (item['price'] ?? 0.0).toDouble() / 100;
      final quantity = ((item['quantity'] ?? 0.0).toDouble() / 1000).round();

      return ReceiptItem(
        name: name,
        price: price,
        quantity: quantity > 0 ? quantity : 1,
      );
    }).toList();

    return Receipt(
      scanMethod: 'qr',
      date: dateTime,
      totalAmount: totalSum,
      retailerName: retailerName,
      retailerInn: userInn,
      items: items,
      qrRaw: qrRaw,
    );
  }

  /// Проверка доступности API
  Future<bool> isApiAvailable() async {
    try {
      final url = Uri.parse('$_baseUrl/status');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
