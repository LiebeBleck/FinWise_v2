import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../services/receipt_categorization_service.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final Receipt receipt;

  const ReceiptPreviewScreen({
    super.key,
    required this.receipt,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  late Receipt _receipt;
  bool _isLoading = true;
  bool _createSeparateTransactions = true; // Создавать отдельные транзакции для товаров

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
    _categorizeItems();
  }

  Future<void> _categorizeItems() async {
    setState(() => _isLoading = true);

    try {
      final service = ReceiptCategorizationService();

      for (var item in _receipt.items) {
        final result = await service.categorizeItem(item.name);
        item.suggestedCategory = result['category'];
        item.categoryConfidence = result['confidence'];
      }
    } catch (e) {
      // Игнорируем ошибки категоризации
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy, HH:mm', 'ru_RU');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Предпросмотр чека'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveTransactions,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Информация о чеке
                _buildReceiptHeader(dateFormat),
                const SizedBox(height: 24),

                // Переключатель режима
                if (_receipt.items.isNotEmpty) ...[
                  _buildModeToggle(),
                  const SizedBox(height: 24),
                ],

                // Список товаров или одна транзакция
                if (_createSeparateTransactions && _receipt.items.isNotEmpty)
                  _buildItemsList()
                else
                  _buildSingleTransaction(),

                const SizedBox(height: 24),

                // Кнопка сохранения
                ElevatedButton.icon(
                  onPressed: _saveTransactions,
                  icon: const Icon(Icons.save),
                  label: Text(
                    _createSeparateTransactions && _receipt.items.isNotEmpty
                        ? 'Сохранить ${_receipt.items.length} транзакций'
                        : 'Сохранить транзакцию',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReceiptHeader(DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _receipt.scanMethod == 'qr'
                    ? Icons.qr_code
                    : Icons.camera_alt,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                _receipt.scanMethod == 'qr'
                    ? 'QR-код сканирование'
                    : 'OCR распознавание',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_receipt.retailerName != null) ...[
            const SizedBox(height: 12),
            Text(
              _receipt.retailerName!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (_receipt.date != null) ...[
            const SizedBox(height: 8),
            Text(
              dateFormat.format(_receipt.date!),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ИТОГО:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_receipt.totalAmount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: 'По товарам',
            isSelected: _createSeparateTransactions,
            onTap: () => setState(() => _createSeparateTransactions = true),
          ),
          _buildModeTab(
            label: 'Одна транзакция',
            isSelected: !_createSeparateTransactions,
            onTap: () => setState(() => _createSeparateTransactions = false),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
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
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Товары (${_receipt.items.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._receipt.items.map((item) => _buildItemCard(item)),
      ],
    );
  }

  Widget _buildItemCard(ReceiptItem item) {
    final category = _getCategoryByName(item.suggestedCategory ?? 'Прочее');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${item.totalPrice.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (item.quantity > 1) ...[
            const SizedBox(height: 4),
            Text(
              '${item.quantity} × ${item.price.toStringAsFixed(2)} ₽',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Категория:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(category),
              if (item.categoryConfidence != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${(item.categoryConfidence! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: item.categoryConfidence! > 0.7
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTransaction() {
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
            'Будет создана одна транзакция',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Описание:'),
              Text(
                _receipt.retailerName ?? 'Покупка по чеку',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Сумма:'),
              Text(
                '${_receipt.totalAmount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(Category? category) {
    if (category == null) {
      return const Chip(
        label: Text('Без категории', style: TextStyle(fontSize: 12)),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    Color categoryColor;
    try {
      categoryColor = Color(int.parse(category.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      categoryColor = Colors.grey;
    }

    return Chip(
      label: Text(
        category.name,
        style: TextStyle(fontSize: 12, color: categoryColor),
      ),
      backgroundColor: categoryColor.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Category? _getCategoryByName(String name) {
    final categoriesBox = Hive.box<Category>('categories');
    for (var category in categoriesBox.values) {
      if (category.name.toLowerCase() == name.toLowerCase()) {
        return category;
      }
    }
    return null;
  }

  void _saveTransactions() {
    final transactionsBox = Hive.box<Transaction>('transactions');
    final receiptDate = _receipt.date ?? DateTime.now();

    if (_createSeparateTransactions && _receipt.items.isNotEmpty) {
      // Создать отдельную транзакцию для каждого товара
      for (var item in _receipt.items) {
        final category = _getCategoryByName(item.suggestedCategory ?? 'Прочее');

        final transaction = Transaction(
          id: const Uuid().v4(),
          amount: -item.totalPrice, // Отрицательное = расход
          categoryId: category?.id ?? 1, // Fallback на ID 1 (Прочее)
          date: receiptDate,
          description: item.name,
          receiptData: _receipt.toJson(),
        );

        transactionsBox.add(transaction);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Создано ${_receipt.items.length} транзакций'),
        ),
      );
    } else {
      // Создать одну транзакцию на всю сумму
      final transaction = Transaction(
        id: const Uuid().v4(),
        amount: -_receipt.totalAmount,
        categoryId: 1, // Прочее
        date: receiptDate,
        description: _receipt.retailerName ?? 'Покупка по чеку',
        receiptData: _receipt.toJson(),
      );

      transactionsBox.add(transaction);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Транзакция создана')),
      );
    }

    // Вернуться на главный экран
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
