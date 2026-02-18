import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import 'package:intl/intl.dart';
import 'search_screen.dart';
import 'calendar_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'month'; // day, week, month, year
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> transactionsBox, _) {
          final allTransactions =
              transactionsBox.values.where((t) => t.isCompleted).toList();
          final filteredTransactions = _filterByPeriod(allTransactions);
          final expenses =
              filteredTransactions.where((t) => t.isExpense).toList();
          final incomes =
              filteredTransactions.where((t) => t.isIncome).toList();

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              // Dark summary card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildDarkSummaryCard(allTransactions),
                ),
              ),

              // Period selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildPeriodSelector(),
                ),
              ),

              // Income & Expenses chart
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child:
                      _buildIncomeExpenseChart(filteredTransactions, expenses, incomes),
                ),
              ),

              // Summary bottom cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildBottomSummaryCards(filteredTransactions),
                ),
              ),

              // Pie chart
              if (expenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildPieChartCard(expenses),
                  ),
                ),

              // Empty state if no data
              if (filteredTransactions.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          // Left: title
          const Expanded(
            child: Text(
              'Аналитика',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Right: search + calendar
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SearchScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CalendarScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDarkSummaryCard(List<Transaction> allTransactions) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Budget>('budget').listenable(),
      builder: (context, Box<Budget> budgetBox, _) {
        final budget = budgetBox.get('current');
        final budgetAmount = budget?.monthlyAmount ?? 0;

        final monthTransactions = allTransactions.where((t) {
          final now = DateTime.now();
          return t.date.year == now.year && t.date.month == now.month;
        }).toList();

        final balance =
            monthTransactions.fold(0.0, (s, t) => s + t.amount);
        final spent = monthTransactions
            .where((t) => t.isExpense)
            .fold(0.0, (s, t) => s + t.absoluteAmount);

        final progress =
            budgetAmount > 0 ? (spent / budgetAmount).clamp(0.0, 1.0) : 0.0;
        final progressPercent = (progress * 100).toStringAsFixed(0);
        final nf = NumberFormat.currency(
            locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

        String tip = '';
        if (budgetAmount > 0) {
          if (progress < 0.5) {
            tip = '$progressPercent% расходов бюджета. Отличный контроль!';
          } else if (progress < 0.8) {
            tip = '$progressPercent% расходов бюджета. Следите за тратами.';
          } else {
            tip = '$progressPercent% расходов бюджета. Бюджет почти исчерпан!';
          }
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Balance + Expense row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: Colors.white54, size: 13),
                            SizedBox(width: 4),
                            Text('Общий баланс',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nf.format(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 44, color: Colors.white12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_down,
                                  color: Colors.white54, size: 13),
                              SizedBox(width: 4),
                              Text('Расходы месяца',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '-${nf.format(spent)}',
                            style: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (budgetAmount > 0) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$progressPercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.9
                                ? const Color(0xFFFF5252)
                                : progress > 0.7
                                    ? const Color(0xFFFFD740)
                                    : AppTheme.primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      nf.format(budgetAmount),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (tip.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppTheme.primaryColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        tip,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      ('День', 'day'),
      ('Неделя', 'week'),
      ('Месяц', 'month'),
      ('Год', 'year'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: periods.map((p) {
          final isSelected = _selectedPeriod == p.$2;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedPeriod = p.$2;
                _touchedIndex = -1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncomeExpenseChart(
    List<Transaction> filtered,
    List<Transaction> expenses,
    List<Transaction> incomes,
  ) {
    final incomeGrouped = _groupByPeriod(incomes);
    final expenseGrouped = _groupByPeriod(expenses);

    // Merge keys
    final allKeys = <int>{
      ...incomeGrouped.keys,
      ...expenseGrouped.keys,
    }.toList()
      ..sort();

    final barGroups = allKeys.map((key) {
      return BarChartGroupData(
        x: key,
        groupVertically: false,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: incomeGrouped[key] ?? 0,
            color: const Color(0xFF22C55E),
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: expenseGrouped[key] ?? 0,
            color: AppTheme.primaryColor,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final allValues = [
      ...incomeGrouped.values,
      ...expenseGrouped.values,
    ];
    final maxY = allValues.isEmpty
        ? 1000.0
        : _calculateMaxYFromValues(allValues.reduce((a, b) => a > b ? a : b));
    final gridInterval = _getGridInterval(maxY);

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Доходы и Расходы',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // Legend
                  Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          )),
                      const SizedBox(width: 4),
                      const Text('Д',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          )),
                      const SizedBox(width: 4),
                      const Text('Р',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (barGroups.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text('Нет данных за период',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'Доход' : 'Расход';
                        final nf = NumberFormat.currency(
                            locale: 'ru_RU', symbol: '₽', decimalDigits: 0);
                        return BarTooltipItem(
                          '$label\n${nf.format(rod.toY)}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _getBottomTitle(value.toInt()),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: gridInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatShortAmount(value),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade100,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSummaryCards(List<Transaction> transactions) {
    final income = transactions
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.absoluteAmount);
    final expense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.absoluteAmount);
    final nf =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up,
                      color: Color(0xFF22C55E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Доходы',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        nf.format(income),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_down,
                      color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Расходы',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        nf.format(expense),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartCard(List<Transaction> expenses) {
    final categoryTotals = _calculateCategoryTotals(expenses);
    final total =
        categoryTotals.values.fold(0.0, (s, ct) => s + ct.amount);
    final nf =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Распределение расходов',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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
                sections: _buildPieChartSections(categoryTotals),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
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
                    child: Text(entry.key,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nf.format(entry.value.amount),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_outlined,
                size: 56, color: AppTheme.primaryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Нет данных за период',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте транзакции для просмотра аналитики',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Data helpers ──────────────────────────────────────

  List<Transaction> _filterByPeriod(List<Transaction> transactions) {
    final today = DateTime.now().dateOnly;

    return transactions.where((t) {
      switch (_selectedPeriod) {
        case 'day':
          return t.date.isSameDay(today);
        case 'week':
          final weekStart = today.startOfWeek;
          final weekEnd = today.endOfWeek;
          return !t.date.isBefore(weekStart) && !t.date.isAfter(weekEnd);
        case 'month':
          return t.date.year == today.year && t.date.month == today.month;
        case 'year':
          return t.date.year == today.year;
        default:
          return true;
      }
    }).toList();
  }

  Map<int, double> _groupByPeriod(List<Transaction> transactions) {
    final Map<int, double> grouped = {};

    for (final t in transactions) {
      int key;
      switch (_selectedPeriod) {
        case 'day':
          key = t.date.hour;
          break;
        case 'week':
          key = t.date.weekday; // 1=Mon … 7=Sun
          break;
        case 'month':
          key = t.date.day;
          break;
        case 'year':
          key = t.date.month; // 1-12
          break;
        default:
          key = t.date.day;
      }
      grouped[key] = (grouped[key] ?? 0) + t.absoluteAmount;
    }

    return Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  String _getBottomTitle(int value) {
    switch (_selectedPeriod) {
      case 'day':
        return '${value}ч';
      case 'week':
        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        return (value >= 1 && value <= 7) ? days[value - 1] : '';
      case 'month':
        return '$value';
      case 'year':
        const months = [
          'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
          'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
        ];
        return (value >= 1 && value <= 12) ? months[value - 1] : '';
      default:
        return '$value';
    }
  }

  String _formatShortAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}М';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}к';
    return value.toStringAsFixed(0);
  }

  double _calculateMaxYFromValues(double maxValue) {
    final targetMax = maxValue * 1.2;
    if (targetMax <= 1000) return (targetMax / 100).ceil() * 100.0;
    if (targetMax <= 10000) return (targetMax / 1000).ceil() * 1000.0;
    return (targetMax / 5000).ceil() * 5000.0;
  }

  double _getGridInterval(double maxY) {
    if (maxY <= 1000) return 200;
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    return 5000;
  }

  List<PieChartSectionData> _buildPieChartSections(
      Map<String, CategoryTotal> categoryTotals) {
    final total =
        categoryTotals.values.fold(0.0, (s, ct) => s + ct.amount);
    return categoryTotals.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final ct = entry.value.value;
      final isTouched = index == _touchedIndex;
      final pct = (ct.amount / total * 100);

      return PieChartSectionData(
        color: ct.color,
        value: ct.amount,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 72 : 60,
        titleStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Map<String, CategoryTotal> _calculateCategoryTotals(
      List<Transaction> expenses) {
    final Map<String, CategoryTotal> totals = {};
    final categoriesBox = Hive.box<Category>('categories');

    for (final expense in expenses) {
      final cat = categoriesBox.get(expense.categoryId);
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
        totals[name] = CategoryTotal(amount: 0, color: color);
      }
      totals[name]!.amount += expense.absoluteAmount;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    return Map.fromEntries(sorted);
  }
}

class CategoryTotal {
  double amount;
  final Color color;
  CategoryTotal({required this.amount, required this.color});
}
