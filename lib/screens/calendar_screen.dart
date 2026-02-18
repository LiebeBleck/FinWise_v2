import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  String _activeTab = 'spends'; // 'spends' or 'categories'
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> box, _) {
          final allTransactions =
              box.values.where((t) => t.isCompleted).toList();

          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Calendar card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildMonthHeader(),
                            _buildCalendarGrid(allTransactions),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Toggle buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildToggle(),
                      ),

                      const SizedBox(height: 16),

                      // Content
                      if (_activeTab == 'spends')
                        _buildSpendsContent(allTransactions)
                      else
                        _buildCategoriesContent(allTransactions),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 8,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Календарь',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthFormat = DateFormat('MMMM', 'ru_RU');
    final yearFormat = DateFormat('yyyy');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                _selectedDate = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryColor, size: 20),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${monthFormat.format(_focusedMonth)[0].toUpperCase()}${monthFormat.format(_focusedMonth).substring(1)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  yearFormat.format(_focusedMonth),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                _selectedDate = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right,
                  color: AppTheme.primaryColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(List<Transaction> transactions) {
    const weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // weekday: 1=Mon, 7=Sun
    final firstWeekday = _focusedMonth.weekday; // 1-7
    final totalCells = firstWeekday - 1 + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Get days that have transactions
    final daysWithTransactions = <int>{};
    for (final t in transactions) {
      if (t.date.year == _focusedMonth.year &&
          t.date.month == _focusedMonth.month) {
        daysWithTransactions.add(t.date.day);
      }
    }

    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Week day headers
          Row(
            children: weekDays
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == 'Сб' || d == 'Вс'
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar days
          for (int row = 0; row < rows; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - (firstWeekday - 1) + 1;

                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }

                final date =
                    DateTime(_focusedMonth.year, _focusedMonth.month, day);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = _selectedDate != null &&
                    date.year == _selectedDate!.year &&
                    date.month == _selectedDate!.month &&
                    date.day == _selectedDate!.day;
                final hasTransactions = daysWithTransactions.contains(day);
                final isWeekend = col >= 5;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : isToday
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? AppTheme.primaryColor
                                      : isWeekend
                                          ? Colors.grey[400]
                                          : const Color(0xFF1E1E1E),
                            ),
                          ),
                          if (hasTransactions && !isSelected)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryColor.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleTab('Расходы', 'spends'),
          _buildToggleTab('Категории', 'categories'),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String label, String value) {
    final isSelected = _activeTab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeTab = value;
          _touchedIndex = -1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendsContent(List<Transaction> allTransactions) {
    List<Transaction> dayTransactions;

    if (_selectedDate != null) {
      dayTransactions = allTransactions
          .where((t) =>
              t.date.year == _selectedDate!.year &&
              t.date.month == _selectedDate!.month &&
              t.date.day == _selectedDate!.day)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } else {
      // Show current month if no date selected
      dayTransactions = allTransactions
          .where((t) =>
              t.date.year == _focusedMonth.year &&
              t.date.month == _focusedMonth.month)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }

    if (dayTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  _selectedDate != null
                      ? 'Нет транзакций за этот день'
                      : 'Нет транзакций за этот месяц',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _selectedDate != null
                  ? DateFormat('d MMMM', 'ru_RU').format(_selectedDate!)
                  : DateFormat('MMMM yyyy', 'ru_RU').format(_focusedMonth),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...dayTransactions.map((t) => _buildTransactionItem(t)),
        ],
      ),
    );
  }

  Widget _buildCategoriesContent(List<Transaction> allTransactions) {
    // Show categories for selected month
    final monthTransactions = allTransactions
        .where((t) =>
            t.date.year == _focusedMonth.year &&
            t.date.month == _focusedMonth.month &&
            t.isExpense)
        .toList();

    if (monthTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Нет расходов за этот месяц',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final categoryTotals = _calculateCategoryTotals(monthTransactions);
    final total = categoryTotals.values.fold(0.0, (s, ct) => s + ct.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pie chart
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex =
                            response.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 55,
                  sections: _buildPieSections(categoryTotals, total),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Legend
            ...categoryTotals.entries.map((entry) {
              final pct = (entry.value.amount / total * 100);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entry.value.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      NumberFormat.currency(
                              locale: 'ru_RU', symbol: '₽', decimalDigits: 0)
                          .format(entry.value.amount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      Map<String, _CategoryTotal> totals, double total) {
    final entries = totals.entries.toList();
    return entries.asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final isTouched = index == _touchedIndex;
      final pct = entry.value.amount / total * 100;

      return PieChartSectionData(
        color: entry.value.color,
        value: entry.value.amount,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 70 : 58,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final categoriesBox = Hive.box<Category>('categories');
    final category = categoriesBox.get(transaction.categoryId);
    final categoryName = category?.name ?? 'Без категории';

    Color categoryColor;
    try {
      categoryColor = Color(
        int.parse(category?.color.replaceFirst('#', '0xFF') ?? '0xFFF97316'),
      );
    } catch (e) {
      categoryColor = AppTheme.primaryColor;
    }

    final timeFormat = DateFormat('HH:mm', 'ru_RU');
    final dateFormat = DateFormat('d MMM', 'ru_RU');
    final numberFormat =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                transaction.isIncome
                    ? Icons.trending_up
                    : Icons.shopping_bag_outlined,
                color: categoryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty
                        ? transaction.description
                        : categoryName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(transaction.date)} — ${dateFormat.format(transaction.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  '${transaction.isIncome ? '+' : '-'}${numberFormat.format(transaction.absoluteAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: transaction.isIncome
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, _CategoryTotal> _calculateCategoryTotals(
      List<Transaction> transactions) {
    final Map<String, _CategoryTotal> totals = {};
    final categoriesBox = Hive.box<Category>('categories');

    for (final t in transactions) {
      final cat = categoriesBox.get(t.categoryId);
      final name = cat?.name ?? 'Без категории';

      if (!totals.containsKey(name)) {
        Color color;
        try {
          color = cat != null
              ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
              : Colors.grey;
        } catch (e) {
          color = Colors.grey;
        }
        totals[name] = _CategoryTotal(amount: 0, color: color);
      }
      totals[name]!.amount += t.absoluteAmount;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    return Map.fromEntries(sorted);
  }
}

class _CategoryTotal {
  double amount;
  final Color color;
  _CategoryTotal({required this.amount, required this.color});
}
