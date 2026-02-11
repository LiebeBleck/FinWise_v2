import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'month'; // day, week, month
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Аналитика'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: More filters
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> transactionsBox, _) {
          final transactions = transactionsBox.values.toList();
          final filteredTransactions = _filterByPeriod(transactions);
          final expenses = filteredTransactions.where((t) => t.isExpense).toList();

          if (filteredTransactions.isEmpty) {
            return _buildEmptyState();
          }

          return CustomScrollView(
            slivers: [
              // Period Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPeriodSelector(),
                ),
              ),

              // Summary Cards
              SliverToBoxAdapter(
                child: _buildSummaryCards(filteredTransactions),
              ),

              // Pie Chart (Distribution by Categories)
              if (expenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Распределение по категориям',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPieChart(expenses),
                        const SizedBox(height: 16),
                        _buildCategoryLegend(expenses),
                      ],
                    ),
                  ),
                ),

              // Bar Chart (Spending over time)
              if (expenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Динамика расходов',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildBarChart(expenses),
                      ],
                    ),
                  ),
                ),

              // No expenses message
              if (expenses.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.insights_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет расходов за период',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте расходы, чтобы увидеть аналитику',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет данных для анализа',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте транзакции для просмотра статистики',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodTab('День', 'day'),
          _buildPeriodTab('Неделя', 'week'),
          _buildPeriodTab('Месяц', 'month'),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
            _touchedIndex = -1;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<Transaction> transactions) {
    final numberFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    final income = transactions
        .where((t) => t.isIncome)
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenses = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);

    final balance = income - expenses;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              title: 'Доходы',
              amount: income,
              color: Colors.green,
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              title: 'Расходы',
              amount: expenses,
              color: Colors.red,
              icon: Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              title: 'Баланс',
              amount: balance,
              color: balance >= 0 ? Colors.blue : Colors.orange,
              icon: Icons.account_balance_wallet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0).format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<Transaction> expenses) {
    final categoryTotals = _calculateCategoryTotals(expenses);

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: _buildPieChartSections(categoryTotals),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, CategoryTotal> categoryTotals) {
    final total = categoryTotals.values.fold(0.0, (sum, ct) => sum + ct.amount);

    return categoryTotals.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final categoryTotal = entry.value.value;
      final isTouched = index == _touchedIndex;
      final percentage = (categoryTotal.amount / total * 100);

      return PieChartSectionData(
        color: categoryTotal.color,
        value: categoryTotal.amount,
        title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 70 : 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryLegend(List<Transaction> expenses) {
    final categoryTotals = _calculateCategoryTotals(expenses);
    final numberFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Column(
      children: categoryTotals.entries.map((entry) {
        final categoryName = entry.key;
        final categoryTotal = entry.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: categoryTotal.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  categoryName,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                numberFormat.format(categoryTotal.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(List<Transaction> expenses) {
    final barGroups = _buildBarGroups(expenses);

    if (barGroups.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Нет данных')),
      );
    }

    // Calculate once to avoid multiple calls
    final maxY = _calculateMaxY(expenses);
    final gridInterval = _getGridInterval(maxY);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final value = rod.toY;
                return BarTooltipItem(
                  NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0)
                      .format(value),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _getBottomTitle(value.toInt()),
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: gridInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatShortAmount(value),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: gridInterval,
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<Transaction> expenses) {
    final groupedByPeriod = _groupByPeriod(expenses);

    return groupedByPeriod.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: AppTheme.primaryColor,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  Map<int, double> _groupByPeriod(List<Transaction> expenses) {
    final Map<int, double> grouped = {};

    for (var expense in expenses) {
      int key;
      switch (_selectedPeriod) {
        case 'day':
          key = expense.date.hour;
          break;
        case 'week':
          key = expense.date.weekday;
          break;
        case 'month':
          key = expense.date.day;
          break;
        default:
          key = expense.date.day;
      }

      grouped[key] = (grouped[key] ?? 0) + expense.absoluteAmount;
    }

    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  String _getBottomTitle(int value) {
    switch (_selectedPeriod) {
      case 'day':
        return '${value}ч';
      case 'week':
        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        return value > 0 && value <= 7 ? days[value - 1] : '';
      case 'month':
        return value.toString();
      default:
        return value.toString();
    }
  }

  String _formatShortAmount(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}к';
    }
    return value.toStringAsFixed(0);
  }

  double _calculateMaxY(List<Transaction> expenses) {
    final grouped = _groupByPeriod(expenses);
    if (grouped.isEmpty) return 1000;

    final maxValue = grouped.values.reduce((a, b) => a > b ? a : b);
    final targetMax = maxValue * 1.2;

    // Round to nice number for clean grid
    if (targetMax <= 1000) {
      return (targetMax / 100).ceil() * 100; // Round to nearest 100
    } else if (targetMax <= 10000) {
      return (targetMax / 1000).ceil() * 1000; // Round to nearest 1000
    } else {
      return (targetMax / 5000).ceil() * 5000; // Round to nearest 5000
    }
  }

  double _getGridInterval(double maxY) {
    // Calculate nice interval for 5 grid lines
    if (maxY <= 1000) {
      return 200; // 0, 200, 400, 600, 800, 1000
    } else if (maxY <= 5000) {
      return 1000; // 0, 1k, 2k, 3k, 4k, 5k
    } else if (maxY <= 10000) {
      return 2000; // 0, 2k, 4k, 6k, 8k, 10k
    } else {
      return 5000; // 0, 5k, 10k, 15k, 20k, 25k
    }
  }

  Map<String, CategoryTotal> _calculateCategoryTotals(List<Transaction> expenses) {
    final Map<String, CategoryTotal> totals = {};
    final categoriesBox = Hive.box<Category>('categories');

    for (var expense in expenses) {
      final categoryItem = categoriesBox.get(expense.categoryId);
      final categoryName = categoryItem?.name ?? 'Без категории';

      if (!totals.containsKey(categoryName)) {
        Color color;
        try {
          color = categoryItem != null
              ? Color(int.parse(categoryItem.color.replaceFirst('#', '0xFF')))
              : Colors.grey;
        } catch (e) {
          color = Colors.grey;
        }

        totals[categoryName] = CategoryTotal(amount: 0, color: color);
      }

      totals[categoryName]!.amount += expense.absoluteAmount;
    }

    // Sort by amount (descending)
    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return Map.fromEntries(sortedEntries);
  }

  List<Transaction> _filterByPeriod(List<Transaction> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime startDate;
    DateTime? endDate;

    switch (_selectedPeriod) {
      case 'day':
        startDate = today;
        endDate = today.add(const Duration(days: 1));
        break;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    return transactions.where((t) {
      final transactionDate = DateTime(t.date.year, t.date.month, t.date.day);

      if (endDate != null) {
        // For day filter: transaction must be on the same day
        return transactionDate.isAtSameMomentAs(startDate) ||
               (transactionDate.isAfter(startDate) && transactionDate.isBefore(endDate));
      } else {
        // For week and month: transaction must be after or on start date
        return transactionDate.isAfter(startDate) || transactionDate.isAtSameMomentAs(startDate);
      }
    }).toList();
  }
}

class CategoryTotal {
  double amount;
  final Color color;

  CategoryTotal({required this.amount, required this.color});
}
