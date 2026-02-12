import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isIncome;
  final Transaction? transaction; // For editing

  const AddTransactionScreen({
    super.key,
    this.isIncome = false,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late bool _isIncome;
  int? _selectedCategoryId;
  late DateTime _selectedDate;

  // Планируемые траты
  bool _isPlanned = false;
  DateTime? _plannedDate;
  bool _isRecurring = false;
  String? _recurrenceRule;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.isIncome;

    // Инициализация даты с обнуленным временем
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.absoluteAmount.toString();
      _descriptionController.text = widget.transaction!.description;
      _selectedCategoryId = widget.transaction!.categoryId;
      _selectedDate = widget.transaction!.date;
      _isIncome = widget.transaction!.isIncome;
      _isPlanned = widget.transaction!.isPlanned;
      _plannedDate = widget.transaction!.plannedDate;
      _isRecurring = widget.transaction!.isRecurring;
      _recurrenceRule = widget.transaction!.recurrenceRule;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null
            ? 'Редактировать'
            : _isIncome
                ? 'Добавить доход'
                : 'Добавить расход'),
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteTransaction,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selector
            _buildTypeSelector(),
            const SizedBox(height: 24),

            // Amount Input
            _buildAmountInput(),
            const SizedBox(height: 16),

            // Category Selector
            _buildCategorySelector(),
            const SizedBox(height: 16),

            // Description Input
            _buildDescriptionInput(),
            const SizedBox(height: 16),

            // Date Picker
            _buildDatePicker(),
            const SizedBox(height: 24),

            // === Планируемые траты (v1.1) ===
            _buildPlannedTransactionToggle(),
            if (_isPlanned) ...[
              const SizedBox(height: 16),
              _buildPlannedDatePicker(),
              const SizedBox(height: 16),
              _buildRecurringToggle(),
              if (_isRecurring) ...[
                const SizedBox(height: 16),
                _buildRecurrenceRuleSelector(),
              ],
            ],
            const SizedBox(height: 32),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeTab(
              label: 'Расход',
              isSelected: !_isIncome,
              onTap: () => setState(() => _isIncome = false),
            ),
          ),
          Expanded(
            child: _buildTypeTab(
              label: 'Доход',
              isSelected: _isIncome,
              onTap: () => setState(() => _isIncome = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: 'Сумма',
        hintText: '0',
        prefixText: '₽ ',
        prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Введите сумму';
        }
        if (double.tryParse(value) == null) {
          return 'Введите корректное число';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Category>('categories').listenable(),
      builder: (context, Box<Category> box, _) {
        // Filter categories based on transaction type
        final allCategories = box.values.toList();
        final categories = allCategories.where((category) {
          if (_isIncome) {
            return category.type == 'income' || category.type == 'both';
          } else {
            return category.type == 'expense' || category.type == 'both';
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isIncome ? 'Источник дохода' : 'Категория расхода',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final isSelected = _selectedCategoryId == category.id;
                return _buildCategoryChip(category, isSelected);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(Category category, bool isSelected) {
    Color color;
    try {
      color = Color(int.parse(category.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      color = Colors.grey;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = category.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[200],
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Описание (необязательно)',
        hintText: 'Например: Продукты в Пятёрочке',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: 2,
    );
  }

  Widget _buildDatePicker() {
    final dateFormat = DateFormat('d MMMM yyyy', 'ru_RU');

    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Дата',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveTransaction,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        widget.transaction != null ? 'Сохранить' : 'Добавить',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlannedTransactionToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Планируемая трата',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Запланировать на будущее',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPlanned,
            onChanged: (value) {
              setState(() {
                _isPlanned = value;
                if (!value) {
                  // Сбросить настройки при отключении
                  _plannedDate = null;
                  _isRecurring = false;
                  _recurrenceRule = null;
                } else {
                  // Установить дату по умолчанию (завтра)
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  _plannedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
                }
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPlannedDatePicker() {
    final dateFormat = DateFormat('d MMMM yyyy', 'ru_RU');

    return InkWell(
      onTap: _selectPlannedDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.alarm, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Когда выполнить',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _plannedDate != null
                        ? dateFormat.format(_plannedDate!)
                        : 'Выберите дату',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.repeat, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Повторяющаяся',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Автоматически создавать',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isRecurring,
            onChanged: (value) {
              setState(() {
                _isRecurring = value;
                if (!value) {
                  _recurrenceRule = null;
                } else {
                  _recurrenceRule = 'monthly'; // По умолчанию - ежемесячно
                }
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceRuleSelector() {
    final rules = [
      {'value': 'daily', 'label': 'Ежедневно', 'icon': Icons.today},
      {'value': 'weekly', 'label': 'Еженедельно', 'icon': Icons.view_week},
      {'value': 'monthly', 'label': 'Ежемесячно', 'icon': Icons.calendar_month},
      {'value': 'yearly', 'label': 'Ежегодно', 'icon': Icons.calendar_today},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Частота повторения',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rules.map((rule) {
              final isSelected = _recurrenceRule == rule['value'];
              return GestureDetector(
                onTap: () => setState(() => _recurrenceRule = rule['value'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : Colors.grey[200],
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rule['icon'] as IconData,
                        size: 18,
                        color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rule['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPlannedDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? tomorrow,
      firstDate: tomorrow, // Можно планировать только на будущее
      lastDate: DateTime(now.year + 2, 12, 31), // До 2 лет вперёд
    );

    if (date != null && mounted) {
      setState(() {
        _plannedDate = DateTime(date.year, date.month, date.day);
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) || _selectedDate.isAfter(today.add(const Duration(days: 365)))
          ? today
          : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)), // Allow up to 1 year in future
    );

    if (date != null && mounted) {
      setState(() {
        // Устанавливаем дату с обнуленным временем (00:00:00)
        _selectedDate = DateTime(date.year, date.month, date.day);
      });
    }
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию')),
      );
      return;
    }

    // Валидация планируемой траты
    if (_isPlanned && _plannedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату планируемой траты')),
      );
      return;
    }

    if (_isRecurring && _recurrenceRule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите правило повторения')),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    final box = Hive.box<Transaction>('transactions');

    // Рассчитать nextRecurrenceDate если повторяющаяся
    DateTime? nextRecurrence;
    if (_isRecurring && _plannedDate != null && _recurrenceRule != null) {
      nextRecurrence = _calculateNextRecurrence(_plannedDate!, _recurrenceRule!);
    }

    if (widget.transaction != null) {
      // Edit existing
      widget.transaction!.amount = _isIncome ? amount : -amount;
      widget.transaction!.categoryId = _selectedCategoryId!;
      widget.transaction!.description = _descriptionController.text;
      widget.transaction!.date = _selectedDate;
      widget.transaction!.isPlanned = _isPlanned;
      widget.transaction!.plannedDate = _plannedDate;
      widget.transaction!.isRecurring = _isRecurring;
      widget.transaction!.recurrenceRule = _recurrenceRule;
      widget.transaction!.nextRecurrenceDate = nextRecurrence;
      widget.transaction!.save();
    } else {
      // Create new
      final transaction = Transaction(
        id: const Uuid().v4(),
        amount: _isIncome ? amount : -amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        description: _descriptionController.text,
        isPlanned: _isPlanned,
        plannedDate: _plannedDate,
        isRecurring: _isRecurring,
        recurrenceRule: _recurrenceRule,
        nextRecurrenceDate: nextRecurrence,
      );
      box.add(transaction);
    }

    Navigator.of(context).pop();
  }

  /// Рассчитать следующую дату повторения
  DateTime _calculateNextRecurrence(DateTime currentDate, String rule) {
    switch (rule) {
      case 'daily':
        return currentDate.add(const Duration(days: 1));
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'monthly':
        // Добавляем 1 месяц
        final nextMonth = currentDate.month == 12 ? 1 : currentDate.month + 1;
        final nextYear = currentDate.month == 12 ? currentDate.year + 1 : currentDate.year;
        return DateTime(nextYear, nextMonth, currentDate.day);
      case 'yearly':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate;
    }
  }

  void _deleteTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить транзакцию?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              widget.transaction!.delete();
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
