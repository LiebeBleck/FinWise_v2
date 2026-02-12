/// Модель для данных чека
class Receipt {
  final String scanMethod; // 'qr' или 'ocr'
  final DateTime? date;
  final double totalAmount;
  final String? retailerName;
  final String? retailerInn;
  final List<ReceiptItem> items;
  final String? qrRaw; // Сырые данные QR (для отладки)

  Receipt({
    required this.scanMethod,
    this.date,
    required this.totalAmount,
    this.retailerName,
    this.retailerInn,
    required this.items,
    this.qrRaw,
  });

  /// Создать из QR-кода
  factory Receipt.fromQR(String qrData) {
    // Парсинг QR формата ФНС: t=20240115T1430&s=1250.00&fn=...&i=...&fp=...&n=1
    final params = Uri.splitQueryString(qrData);

    DateTime? date;
    if (params.containsKey('t')) {
      try {
        // Формат: 20240115T1430
        final dateStr = params['t']!;
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = dateStr.length > 9 ? int.parse(dateStr.substring(9, 11)) : 0;
        final minute = dateStr.length > 11 ? int.parse(dateStr.substring(11, 13)) : 0;
        date = DateTime(year, month, day, hour, minute);
      } catch (e) {
        // Игнорируем ошибки парсинга даты
      }
    }

    final amount = double.tryParse(params['s'] ?? '0') ?? 0.0;

    return Receipt(
      scanMethod: 'qr',
      date: date,
      totalAmount: amount,
      qrRaw: qrData,
      items: [], // Товары получим через API ФНС (в будущем)
    );
  }

  /// Создать из OCR текста
  factory Receipt.fromOCR(String ocrText) {
    // Упрощенный парсинг OCR текста
    double totalAmount = 0.0;
    DateTime? date;
    String? retailerName;
    final items = <ReceiptItem>[];

    final lines = ocrText.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Поиск общей суммы (ИТОГО, TOTAL, СУММА)
      if (line.toUpperCase().contains('ИТОГО') ||
          line.toUpperCase().contains('TOTAL') ||
          line.toUpperCase().contains('СУММА')) {
        // Извлечь число из строки
        final match = RegExp(r'(\d+[.,]\d{2})').firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1)!.replaceAll(',', '.');
          totalAmount = double.tryParse(amountStr) ?? totalAmount;
        }
      }

      // Поиск даты (формат: 12.02.2024 или 12/02/2024)
      if (date == null) {
        final dateMatch = RegExp(r'(\d{2})[./](\d{2})[./](\d{4})').firstMatch(line);
        if (dateMatch != null) {
          try {
            final day = int.parse(dateMatch.group(1)!);
            final month = int.parse(dateMatch.group(2)!);
            final year = int.parse(dateMatch.group(3)!);
            date = DateTime(year, month, day);
          } catch (e) {
            // Игнорируем
          }
        }
      }

      // Поиск названия магазина (обычно в первых 5 строках)
      if (i < 5 && retailerName == null && line.length > 3 && line.length < 50) {
        // Название магазина часто содержит буквы и может быть заглавными
        if (RegExp(r'[А-ЯA-Z]{2,}').hasMatch(line)) {
          retailerName = line;
        }
      }

      // Поиск товаров (строка с названием и ценой)
      // Формат: "Товар название    150.00" или "Товар   1х150.00"
      final itemMatch = RegExp(r'^(.+?)\s+(\d+[.,]\d{2})$').firstMatch(line);
      if (itemMatch != null && !line.toUpperCase().contains('ИТОГО')) {
        final name = itemMatch.group(1)!.trim();
        final priceStr = itemMatch.group(2)!.replaceAll(',', '.');
        final price = double.tryParse(priceStr);

        if (price != null && name.length > 2) {
          items.add(ReceiptItem(
            name: name,
            price: price,
            quantity: 1,
          ));
        }
      }
    }

    return Receipt(
      scanMethod: 'ocr',
      date: date,
      totalAmount: totalAmount,
      retailerName: retailerName,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scan_method': scanMethod,
      'date': date?.toIso8601String(),
      'total_amount': totalAmount,
      'retailer_name': retailerName,
      'retailer_inn': retailerInn,
      'items': items.map((item) => item.toJson()).toList(),
      'qr_raw': qrRaw,
    };
  }
}

/// Товар в чеке
class ReceiptItem {
  final String name;
  final double price;
  final int quantity;
  String? suggestedCategory; // Предложенная ML категория
  double? categoryConfidence; // Уверенность ML

  ReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.suggestedCategory,
    this.categoryConfidence,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'suggested_category': suggestedCategory,
      'category_confidence': categoryConfidence,
    };
  }
}
