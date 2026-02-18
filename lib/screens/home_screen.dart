import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_list_item.dart';
import 'add_transaction_screen.dart';
import 'scan_receipt_screen.dart';
import 'notifications_screen.dart';

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
      backgroundColor: const Color(0xFFFAFAFA),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Transaction>('transactions').listenable(),
        builder: (context, Box<Transaction> transactionsBox, _) {
          final transactions = transactionsBox.values.toList();
          final filteredTransactions = _filterByPeriod(transactions);
          final plannedTransactions = _getPlannedTransactions(transactions);

          final balance = _calculateBalance(filteredTransactions);
          final spent = _calculateSpent(filteredTransactions);
          final income = _calculateIncome(filteredTransactions);

          return CustomScrollView(
            slivers: [
              // Custom Header with gradient
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Account Balance Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildAccountBalanceCard(balance, spent, income),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionButton(
                              icon: Icons.add_circle_outline,
                              label: 'Добавить',
                              onTap: () => _navigateToAddTransaction(false),
                              isLeft: true,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            thickness: 1.5,
                            color: Colors.grey.shade200,
                            indent: 12,
                            endIndent: 12,
                          ),
                          Expanded(
                            child: _buildQuickActionButton(
                              icon: Icons.qr_code_scanner,
                              label: 'Сканировать',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ScanReceiptScreen(),
                                  ),
                                );
                              },
                              isLeft: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Planned Transactions
              if (plannedTransactions.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${plannedTransactions.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
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
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // Period Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildPeriodSelector(),
                ),
              ),

              // Transactions List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Транзакции',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filteredTransactions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: AppTheme.primaryColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Нет транзакций',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E1E1E),
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
                          _editTransaction(transaction);
                        },
                      );
                    },
                    childCount: filteredTransactions.length,
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTransaction(false),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<User>('users').listenable(),
      builder: (context, Box<User> usersBox, _) {
        final user = usersBox.isNotEmpty ? usersBox.values.first : null;
        final username = user?.username ?? 'Пользователь';

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
              // Левая часть: приветствие
              Expanded(
                child: Row(
                  children: [
                    // Аватар-иконка
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Привет,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Правая часть: колокольчик
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountBalanceCard(double balance, double spent, double income) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Budget>('budget').listenable(),
      builder: (context, Box<Budget> budgetBox, _) {
        final budget = budgetBox.get('current');
        final budgetAmount = budget?.monthlyAmount ?? 0;
        final progress = budgetAmount > 0 ? (spent / budgetAmount).clamp(0.0, 1.0) : 0.0;
        final progressPercent = (progress * 100).toStringAsFixed(0);

        final numberFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

        String motivationalMsg = '';
        if (budgetAmount > 0) {
          if (progress < 0.5) {
            motivationalMsg = '$progressPercent% расходов бюджета. Отличный контроль!';
          } else if (progress < 0.8) {
            motivationalMsg = '$progressPercent% расходов бюджета. Следите за тратами.';
          } else if (progress < 1.0) {
            motivationalMsg = '$progressPercent% расходов бюджета. Бюджет почти исчерпан!';
          } else {
            motivationalMsg = 'Бюджет превышен на ${numberFormat.format(spent - budgetAmount)}!';
          }
        }

        return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top gradient section: Balance + Expense
                GestureDetector(
                  onLongPress: _showSetBudgetDialog,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Total Balance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: Colors.white54,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Общий баланс',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    numberFormat.format(balance),
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
                            // Total Expense
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.trending_down,
                                          color: Colors.white54,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Расходы месяца',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '-${numberFormat.format(spent)}',
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
                          const SizedBox(height: 18),
                          // Progress Bar row
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
                                numberFormat.format(budgetAmount),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom white section: Income / Expense cards + tip
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Income Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Color(0xFF22C55E),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Доходы',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          numberFormat.format(income),
                                          style: const TextStyle(
                                            fontSize: 13,
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
                          // Expense Card
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.trending_down,
                                      color: Color(0xFFEF4444),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Расходы',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          numberFormat.format(spent),
                                          style: const TextStyle(
                                            fontSize: 13,
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
                      ),

                      // Motivational message
                      if (motivationalMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                progress >= 1.0
                                    ? Icons.warning_amber_rounded
                                    : Icons.tips_and_updates_outlined,
                                color: progress >= 1.0
                                    ? const Color(0xFFDC2626)
                                    : AppTheme.primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  motivationalMsg,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: progress >= 1.0
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Set budget button (if no budget)
                      if (budgetAmount == 0) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _showSetBudgetDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Установить месячный бюджет',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLeft = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(16) : Radius.zero,
          right: isLeft ? Radius.zero : const Radius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.all(4),
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
            t.isCompleted &&
            (t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Transaction> _getPlannedTransactions(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isPlanned)
        .toList()
      ..sort((a, b) {
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

  double _calculateIncome(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isIncome)
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

        Color borderColor = Colors.grey.shade200;
        if (transaction.isOverdue) borderColor = Colors.red.shade300;
        if (transaction.isDueSoon) borderColor = Colors.orange.shade300;

        return Container(
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _markAsCompleted(transaction),
              onLongPress: () => _editTransaction(transaction),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: categoryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
                                  : Icons.calendar_today_outlined,
                              size: 13,
                              color: transaction.isOverdue
                                  ? Colors.red
                                  : transaction.isDueSoon
                                      ? Colors.orange
                                      : Colors.grey[500],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 11,
                                color: transaction.isOverdue
                                    ? Colors.red
                                    : transaction.isDueSoon
                                        ? Colors.orange
                                        : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${transaction.absoluteAmount.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.isRecurring) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.repeat, size: 11, color: AppTheme.primaryColor),
                          const SizedBox(width: 3),
                          Text(
                            transaction.recurrenceRuleDisplay,
                            style: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text(
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
        final nextYear =
            currentDate.month == 12 ? currentDate.year + 1 : currentDate.year;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
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
              style: const TextStyle(color: AppTheme.primaryColor),
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
