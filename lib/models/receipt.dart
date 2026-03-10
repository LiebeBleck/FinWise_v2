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

  /// Создать из OCR текста (ML Kit на устройстве)
  factory Receipt.fromOCR(String ocrText) {
    double totalAmount = 0.0;
    DateTime? date;
    String? retailerName;
    final items = <ReceiptItem>[];

    final lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // -- Ключевые слова стоп-строк (не товары) --
    final skipRe = RegExp(
      r'итого?|к\s*оплат|сумм[аы]|наличн|безналич|сдач|скидк|ндс|nds|'
      r'кассир|инн:|рн\s*ккт|зн\s*ккт|фн:|фд:|фп:|место расчет|приход|'
      r'кассов|добро пожалов|www\.|http|сайт',
      caseSensitive: false,
    );

    // -- 1. Ретейлер: ищем кавычки «» "" "" или venue-слово --
    final quoteRe = RegExp(r'[«"\u201c\u2018](.{3,30})[»"\u201d\u2019]');
    final venueRe = RegExp(
      r'ресторан|кафе|магазин|супермаркет|аптека|пятёрочк|пятерочк|'
      r'перекрёст|магнит|дикси|лента|атак|метро|shop|store|market',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length && i < 15; i++) {
      final line = lines[i];
      final qm = quoteRe.firstMatch(line);
      if (qm != null && retailerName == null) {
        retailerName = qm.group(1)!.trim();
        break;
      }
      if (retailerName == null && venueRe.hasMatch(line)) {
        final cleaned = line.replaceFirst(
          RegExp(r'^добро пожаловать в\s+', caseSensitive: false), '');
        if (cleaned.length > 3) retailerName = cleaned.trim();
      }
    }
    // Если кавычки/venue не нашли — первая «чистая» строка (не служебная)
    if (retailerName == null) {
      final serviceRe = RegExp(
        r'чек|расчет|инн|ккт|приход|кассир|www|http|сайт|место',
        caseSensitive: false,
      );
      for (var i = 0; i < lines.length && i < 8; i++) {
        final line = lines[i];
        if (!serviceRe.hasMatch(line) && line.length >= 4 && line.length <= 50) {
          retailerName = line;
          break;
        }
      }
    }

    // -- 2. Сумма: ИТОГ/ИТОГО/К ОПЛАТЕ/TOTAL (последнее совпадение — оно точнее) --
    final totalKeyRe = RegExp(
      r'итого?|к\s*оплат[еи]|total',
      caseSensitive: false,
    );
    // Паттерн суммы: =1570.00 или 1570.00 или 1 570.00
    final amountRe = RegExp(r'[=:]\s*(\d[\d\s]{0,4}[.,]\d{2})');
    final amountAnyRe = RegExp(r'(\d[\d\s]{0,4}[.,]\d{2})');

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (totalKeyRe.hasMatch(line)) {
        final m = amountRe.firstMatch(line) ?? amountAnyRe.firstMatch(line);
        if (m != null) {
          final v = double.tryParse(
            m.group(m.groupCount)!.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
          );
          if (v != null && v > 0) {
            totalAmount = v;
            break;
          }
        }
      }
    }

    // -- 3. Дата: DD.MM.YYYY или DD.MM.YY --
    final dateRe4 = RegExp(r'(\d{2})[./](\d{2})[./](\d{4})');
    final dateRe2 = RegExp(r'(\d{2})[./](\d{2})[./](\d{2})(?:\s|$)');
    for (final line in lines) {
      if (date != null) break;
      var m = dateRe4.firstMatch(line);
      if (m != null) {
        try {
          final d = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          final y = int.parse(m.group(3)!);
          if (y >= 2015 && y <= 2030) date = DateTime(y, mo, d);
        } catch (_) {}
        continue;
      }
      m = dateRe2.firstMatch(line);
      if (m != null) {
        try {
          final d = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          var y = int.parse(m.group(3)!);
          y += y >= 50 ? 1900 : 2000; // 23 → 2023
          if (y >= 2015 && y <= 2030) date = DateTime(y, mo, d);
        } catch (_) {}
      }
    }

    // -- 4. Товары: строки до ИТОГ, с ценой в конце или =цена --
    final itemPriceRe = RegExp(r'=\s*(\d[\d\s]{0,4}[.,]\d{2})\s*$');
    final itemSimpleRe = RegExp(r'^(.+?)\s{2,}(\d[\d\s]{0,4}[.,]\d{2})\s*$');
    bool pastTotal = false;
    for (final line in lines) {
      if (totalKeyRe.hasMatch(line)) { pastTotal = true; break; }
      if (skipRe.hasMatch(line)) continue;

      // Формат =890.00 в конце
      var m = itemPriceRe.firstMatch(line);
      if (m != null) {
        final price = double.tryParse(
          m.group(1)!.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
        );
        if (price != null && price > 0) {
          final name = line
              .replaceFirst(RegExp(r'\d+[.,]\d{2}\s*[*×х]\s*\d+.*$'), '')
              .replaceFirst(RegExp(r'\s*=\s*\d+[.,]\d+\s*$'), '')
              .replaceFirst(RegExp(r'[=\s]+$'), '')
              .trim();
          // Пропускаем строки где имя — просто цена (=250.00) или пусто
          final looksLikePrice = RegExp(r'^[=\s]*\d+[.,]\d{2}$').hasMatch(name);
          if (name.length > 2 && !looksLikePrice) {
            items.add(ReceiptItem(name: name, price: price, quantity: 1));
          }
        }
        continue;
      }

      // Формат "Название   150.00"
      m = itemSimpleRe.firstMatch(line);
      if (m != null) {
        final price = double.tryParse(
          m.group(2)!.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
        );
        final name = m.group(1)!.trim();
        final looksLikePrice = RegExp(r'^[=\s]*\d+[.,]\d{2}$').hasMatch(name);
        if (price != null && price > 0 && name.length > 2 && !looksLikePrice) {
          items.add(ReceiptItem(name: name, price: price, quantity: 1));
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

  /// Создать из ответа серверного OCR endpoint
  factory Receipt.fromServerOCR(Map<String, dynamic> data) {
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;

    DateTime? date;
    if (data['date'] != null) {
      try {
        date = DateTime.parse(data['date'] as String);
      } catch (_) {}
    }

    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData.map((item) {
      final m = item as Map<String, dynamic>;
      // Имя уже очищено на сервере — убираем лишние пробелы по краям
      final rawName = (m['name'] as String? ?? '').trim();
      // Дополнительная защита: если имя выглядит как просто цена (=250.00), пропускаем
      final looksLikePrice = RegExp(r'^[=\s]*\d+[.,]\d{2}$').hasMatch(rawName);
      return looksLikePrice
          ? null
          : ReceiptItem(name: rawName, price: (m['sum'] as num?)?.toDouble() ?? 0.0, quantity: 1);
    }).whereType<ReceiptItem>().where((i) => i.name.isNotEmpty && i.price > 0).toList();

    return Receipt(
      scanMethod: 'ocr',
      date: date,
      totalAmount: total,
      retailerName: data['retailer'] as String?,
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
