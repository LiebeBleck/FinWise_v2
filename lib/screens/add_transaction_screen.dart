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

    final amount = double.parse(_amountController.text);
    final box = Hive.box<Transaction>('transactions');

    if (widget.transaction != null) {
      // Edit existing
      widget.transaction!.amount = _isIncome ? amount : -amount;
      widget.transaction!.categoryId = _selectedCategoryId!;
      widget.transaction!.description = _descriptionController.text;
      widget.transaction!.date = _selectedDate;
      widget.transaction!.save();
    } else {
      // Create new
      final transaction = Transaction(
        id: const Uuid().v4(),
        amount: _isIncome ? amount : -amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        description: _descriptionController.text,
      );
      box.add(transaction);
    }

    Navigator.of(context).pop();
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
