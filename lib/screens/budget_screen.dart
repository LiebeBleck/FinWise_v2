import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/budget_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _numberFormat = NumberFormat('#,##0', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      body: ResponsiveHelper.constrain(
        Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box<Budget>('budget').listenable(),
                builder: (context, Box<Budget> box, _) {
                  final budget = box.get('current');
                  return budget == null
                      ? _buildNoBudget(isDark)
                      : _buildBudgetContent(budget, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      color: AppTheme.primaryColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Бюджеты',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── No budget state ───────────────────────────────────

  Widget _buildNoBudget(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Бюджет не установлен',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Установите бюджет на главном экране\nили добавьте его здесь',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showSetBudgetDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Создать бюджет'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Budget content ────────────────────────────────────

  Widget _buildBudgetContent(Budget budget, bool isDark) {
    final spent = BudgetService.getExpensesForPeriod(budget);
    final remaining = budget.monthlyAmount - spent;
    final progress = budget.monthlyAmount > 0
        ? (spent / budget.monthlyAmount).clamp(0.0, 1.0)
        : 0.0;
    final statuses = BudgetService.getCategoryBudgetStatuses(budget);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Period selector
          _buildPeriodSelector(budget, isDark),

          const SizedBox(height: 16),

          // Overall budget card
          _buildOverallCard(
              budget, spent, remaining, progress, isDark),

          const SizedBox(height: 24),

          // Category budgets header
          Row(
            children: [
              Text(
                'Бюджеты по категориям',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddCategoryBudgetSheet(budget),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (statuses.isEmpty)
            _buildNoCategoryBudgets(isDark)
          else
            ...statuses.map((s) => _buildCategoryBudgetRow(s, budget, isDark)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Period selector ────────────────────────────────────

  Widget _buildPeriodSelector(Budget budget, bool isDark) {
    const periods = ['weekly', 'monthly', 'yearly'];
    const labels = ['Неделя', 'Месяц', 'Год'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = budget.effectivePeriodType == periods[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => _changePeriod(budget, periods[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _changePeriod(Budget budget, String periodType) async {
    budget.periodType = periodType;
    budget.periodStart = BudgetService.calculatePeriodStart(periodType);
    await budget.save();
  }

  // ── Overall budget card ────────────────────────────────

  Widget _buildOverallCard(Budget budget, double spent, double remaining,
      double progress, bool isDark) {
    final isOver = spent > budget.monthlyAmount;
    final progressColor = progress < 0.7
        ? const Color(0xFF22C55E)
        : progress < 0.9
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${BudgetService.periodLabel(budget.effectivePeriodType)} бюджет',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showSetBudgetDialog(budget),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Изменить',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_numberFormat.format(budget.monthlyAmount)} ₽',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Потрачено',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    Text(
                      '${_numberFormat.format(spent)} ₽',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isOver ? 'Перерасход' : 'Остаток',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      '${isOver ? '+' : ''}${_numberFormat.format(remaining.abs())} ₽',
                      style: TextStyle(
                        color: isOver ? Colors.redAccent : const Color(0xFF22C55E),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Category budget rows ───────────────────────────────

  Widget _buildNoCategoryBudgets(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'Добавьте лимиты по категориям\nдля детального контроля расходов',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetRow(
      CategoryBudgetStatus s, Budget budget, bool isDark) {
    final progressColor = s.ratio < 0.7
        ? const Color(0xFF22C55E)
        : s.ratio < 0.9
            ? Colors.orange
            : Colors.red;

    final color = _parseColor(s.categoryColor);

    return Dismissible(
      key: Key('cat_budget_${s.categoryId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        budget.removeCategoryLimit(s.categoryId);
        await budget.save();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      s.categoryName.isNotEmpty
                          ? s.categoryName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.categoryName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${_numberFormat.format(s.spent)} / ${_numberFormat.format(s.limit)} ₽',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.isOverBudget)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Превышен',
                      style: TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  )
                else
                  Text(
                    '${(s.ratio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.ratio.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs & Bottom Sheets ────────────────────────────

  void _showSetBudgetDialog(Budget? existing) {
    final ctrl = TextEditingController(
      text: existing?.monthlyAmount.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Изменить бюджет' : 'Создать бюджет'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Сумма бюджета',
            suffixText: '₽',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              final box = Hive.box<Budget>('budget');
              if (existing != null) {
                existing.monthlyAmount = amount;
                await existing.save();
              } else {
                final periodType = 'monthly';
                await box.put(
                  'current',
                  Budget(
                    monthlyAmount: amount,
                    periodStart:
                        BudgetService.calculatePeriodStart(periodType),
                    periodType: periodType,
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryBudgetSheet(Budget budget) {
    final categories = Hive.box<Category>('categories')
        .values
        .where((c) => c.type == 'expense' || c.type == 'both')
        .where((c) => budget.getCategoryLimit(c.id) == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Все категории расходов уже имеют бюджет')),
      );
      return;
    }

    Category? selectedCategory;
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Добавить бюджет категории',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Category>(
                    decoration: InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    value: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Лимит',
                      suffixText: '₽',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final cat = selectedCategory;
                        final amount = double.tryParse(amountCtrl.text);
                        if (cat == null || amount == null || amount <= 0) return;
                        budget.setCategoryLimit(cat.id, amount);
                        await budget.save();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────

  Color _parseColor(String hex) {
    try {
      return Color(
          int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }
}
