import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/transaction_list_item.dart';
import 'add_transaction_screen.dart';
import 'scan_receipt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPeriod = 'month'; // day, week, month

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('FinWise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Notifications
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> transactionsBox, _) {
          final transactions = transactionsBox.values.toList();
          final filteredTransactions = _filterByPeriod(transactions);
          final plannedTransactions = _getPlannedTransactions(transactions);

          return CustomScrollView(
            slivers: [
              // Budget Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBudgetCard(filteredTransactions),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.add,
                          label: 'Добавить',
                          onTap: () => _navigateToAddTransaction(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.qr_code_scanner,
                          label: 'Сканировать',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ScanReceiptScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // === Планируемые траты (v1.1) ===
              if (plannedTransactions.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.event_available, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Планируемые траты',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${plannedTransactions.length}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: plannedTransactions.length,
                      itemBuilder: (context, index) {
                        return _buildPlannedTransactionCard(
                          plannedTransactions[index],
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Period Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPeriodSelector(),
                ),
              ),

              // Transactions List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Транзакции',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${filteredTransactions.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // Transactions List
              if (filteredTransactions.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет транзакций',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте первую транзакцию',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = filteredTransactions[index];
                      return TransactionListItem(
                        transaction: transaction,
                        onTap: () {
                          // TODO: Navigate to transaction details
                        },
                      );
                    },
                    childCount: filteredTransactions.length,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTransaction(false),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetCard(List<Transaction> transactions) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Budget>('budget').listenable(),
      builder: (context, Box<Budget> budgetBox, _) {
        final budget = budgetBox.get('current');
        if (budget == null) {
          return BudgetProgressCard(
            balance: _calculateBalance(transactions),
            budgetAmount: 0,
            spent: _calculateSpent(transactions),
            onSetBudget: _showSetBudgetDialog,
          );
        }

        return GestureDetector(
          onLongPress: _showSetBudgetDialog,
          child: BudgetProgressCard(
            balance: _calculateBalance(transactions),
            budgetAmount: budget.monthlyAmount,
            spent: _calculateSpent(transactions),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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

  List<Transaction> _filterByPeriod(List<Transaction> transactions) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    return transactions
        .where((t) =>
            t.isCompleted && // Только выполненные транзакции
            (t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Получить планируемые транзакции (отсортированные по дате)
  List<Transaction> _getPlannedTransactions(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isPlanned)
        .toList()
      ..sort((a, b) {
        // Сначала просроченные, потом по дате
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        return (a.plannedDate ?? DateTime.now())
            .compareTo(b.plannedDate ?? DateTime.now());
      });
  }

  double _calculateBalance(List<Transaction> transactions) {
    return transactions.fold(0.0, (sum, t) => sum + t.amount);
  }

  double _calculateSpent(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.absoluteAmount);
  }

  Widget _buildPlannedTransactionCard(Transaction transaction) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('categories').listenable(),
      builder: (context, box, _) {
        final category = box.get(transaction.categoryId);
        final categoryName = category?.name ?? 'Без категории';

        Color categoryColor;
        try {
          categoryColor = Color(
            int.parse(category?.color.replaceFirst('#', '0xFF') ?? '0xFFFF9800'),
          );
        } catch (e) {
          categoryColor = Colors.grey;
        }

        final dateFormat = DateFormat('d MMM', 'ru_RU');
        final dateText = transaction.plannedDate != null
            ? dateFormat.format(transaction.plannedDate!)
            : 'Не указана';

        return Container(
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _markAsCompleted(transaction),
              onLongPress: () => _editTransaction(transaction),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: transaction.isOverdue
                        ? Colors.red.shade300
                        : transaction.isDueSoon
                            ? Colors.orange.shade300
                            : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: categoryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transaction.description.isEmpty
                          ? 'Без описания'
                          : transaction.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              transaction.isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.calendar_today,
                              size: 14,
                              color: transaction.isOverdue
                                  ? Colors.red
                                  : transaction.isDueSoon
                                      ? Colors.orange
                                      : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 12,
                                color: transaction.isOverdue
                                    ? Colors.red
                                    : transaction.isDueSoon
                                        ? Colors.orange
                                        : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${transaction.absoluteAmount.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.isRecurring) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.repeat, size: 12, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            transaction.recurrenceRuleDisplay,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _markAsCompleted(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отметить как выполненную?'),
        content: Text(
          'Трата "${transaction.description}" будет перемещена в историю',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              transaction.isPlanned = false;
              transaction.date = DateTime.now();

              // Если повторяющаяся - создать следующую
              if (transaction.isRecurring && transaction.nextRecurrenceDate != null) {
                final nextTransaction = Transaction(
                  id: const Uuid().v4(),
                  amount: transaction.amount,
                  categoryId: transaction.categoryId,
                  date: transaction.nextRecurrenceDate!,
                  description: transaction.description,
                  isPlanned: true,
                  plannedDate: transaction.nextRecurrenceDate,
                  isRecurring: true,
                  recurrenceRule: transaction.recurrenceRule,
                  nextRecurrenceDate: _calculateNextRecurrence(
                    transaction.nextRecurrenceDate!,
                    transaction.recurrenceRule!,
                  ),
                );
                Hive.box<Transaction>('transactions').add(nextTransaction);
              }

              transaction.save();
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Трата выполнена')),
              );
            },
            child: Text(
              'Выполнить',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _editTransaction(Transaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );
  }

  DateTime _calculateNextRecurrence(DateTime currentDate, String rule) {
    switch (rule) {
      case 'daily':
        return currentDate.add(const Duration(days: 1));
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'monthly':
        final nextMonth = currentDate.month == 12 ? 1 : currentDate.month + 1;
        final nextYear = currentDate.month == 12 ? currentDate.year + 1 : currentDate.year;
        return DateTime(nextYear, nextMonth, currentDate.day);
      case 'yearly':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate;
    }
  }

  void _showSetBudgetDialog() {
    final budgetController = TextEditingController();
    final budgetBox = Hive.box<Budget>('budget');
    final existingBudget = budgetBox.get('current');

    if (existingBudget != null) {
      budgetController.text = existingBudget.monthlyAmount.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingBudget != null ? 'Изменить бюджет' : 'Установить бюджет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Укажите ежемесячный бюджет на расходы',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Сумма бюджета',
                hintText: '0',
                prefixText: '₽ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Бюджет обновляется каждый месяц',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (existingBudget != null)
            TextButton(
              onPressed: () {
                budgetBox.delete('current');
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Бюджет удален')),
                );
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(budgetController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректную сумму')),
                );
                return;
              }

              final now = DateTime.now();
              final budget = Budget(
                monthlyAmount: amount,
                periodStart: DateTime(now.year, now.month, 1),
              );

              budgetBox.put('current', budget);
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    existingBudget != null
                        ? 'Бюджет обновлен: ${amount.toStringAsFixed(0)} ₽'
                        : 'Бюджет установлен: ${amount.toStringAsFixed(0)} ₽',
                  ),
                ),
              );
            },
            child: Text(
              existingBudget != null ? 'Обновить' : 'Установить',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddTransaction(bool isIncome) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(isIncome: isIncome),
      ),
    );
  }
}
