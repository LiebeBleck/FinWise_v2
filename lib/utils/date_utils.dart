/// Утилиты для работы с датами (без времени)
library;

extension DateOnlyExtension on DateTime {
  /// Возвращает дату с обнуленным временем (00:00:00)
  DateTime get dateOnly {
    return DateTime(year, month, day);
  }

  /// Проверяет, совпадает ли день с другой датой
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Проверяет, является ли дата сегодняшним днем
  bool get isToday {
    final now = DateTime.now();
    return isSameDay(now);
  }

  /// Проверяет, является ли дата вчерашним днем
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  /// Начало недели (понедельник)
  DateTime get startOfWeek {
    final daysToSubtract = (weekday - DateTime.monday) % 7;
    return subtract(Duration(days: daysToSubtract)).dateOnly;
  }

  /// Конец недели (воскресенье)
  DateTime get endOfWeek {
    final daysToAdd = (DateTime.sunday - weekday) % 7;
    return add(Duration(days: daysToAdd)).dateOnly;
  }

  /// Начало месяца
  DateTime get startOfMonth {
    return DateTime(year, month, 1);
  }

  /// Конец месяца
  DateTime get endOfMonth {
    return DateTime(year, month + 1, 0);
  }

  /// Относительное описание даты ("Сегодня", "Вчера", "12 янв")
  String toRelativeString() {
    if (isToday) return 'Сегодня';
    if (isYesterday) return 'Вчера';

    // Используем стандартное форматирование для остальных дат
    final months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек'
    ];

    return '$day ${months[month - 1]}';
  }
}

/// Создает дату без времени (00:00:00)
DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// Создает дату из компонентов
DateTime createDate(int year, int month, int day) {
  return DateTime(year, month, day);
}
