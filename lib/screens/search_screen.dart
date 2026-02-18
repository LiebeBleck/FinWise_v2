import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  int? _selectedCategoryId;
  DateTime? _selectedDate;
  String _reportType = 'all'; // 'all', 'income', 'expense'
  List<Transaction> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase().trim();
    final transactionsBox = Hive.box<Transaction>('transactions');
    final all = transactionsBox.values.where((t) => t.isCompleted).toList();

    final filtered = all.where((t) {
      // Text filter
      if (query.isNotEmpty) {
        final desc = t.description.toLowerCase();
        if (!desc.contains(query)) return false;
      }

      // Category filter
      if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) {
        return false;
      }

      // Date filter
      if (_selectedDate != null) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        final selDate = DateTime(
            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        if (tDate != selDate) return false;
      }

      // Type filter
      if (_reportType == 'income' && !t.isIncome) return false;
      if (_reportType == 'expense' && !t.isExpense) return false;

      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _results = filtered;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesBox = Hive.box<Category>('categories');
    final categories = categoriesBox.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск по описанию...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search,
                            color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Filters card
                  Container(
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
                        // Categories
                        const Text(
                          'Категория',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              hint: const Text('Выберите категорию'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Все категории'),
                                ),
                                ...categories.map((cat) {
                                  return DropdownMenuItem<int?>(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategoryId = value);
                              },
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: AppTheme.primaryColor),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Date
                        const Text(
                          'Дата',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppTheme.primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDate != null
                                        ? DateFormat('dd/MMM/yyyy', 'ru_RU')
                                            .format(_selectedDate!)
                                        : 'Любая дата',
                                    style: TextStyle(
                                      color: _selectedDate != null
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (_selectedDate != null)
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedDate = null),
                                        child: const Icon(Icons.close,
                                            size: 16, color: Colors.grey),
                                      ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.calendar_today_outlined,
                                        color: AppTheme.primaryColor, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Report type
                        const Text(
                          'Тип транзакции',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildRadioOption('Все', 'all'),
                            const SizedBox(width: 12),
                            _buildRadioOption('Доходы', 'income'),
                            const SizedBox(width: 12),
                            _buildRadioOption('Расходы', 'expense'),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Search button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _performSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Найти',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Results
                  if (_hasSearched) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'Результаты',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_results.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_results.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Ничего не найдено',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._results.map((t) => _buildResultItem(t)),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
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
              'Поиск',
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

  Widget _buildRadioOption(String label, String value) {
    final isSelected = _reportType == value;
    return GestureDetector(
      onTap: () => setState(() => _reportType = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? const Color(0xFF1E1E1E) : Colors.grey[600],
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(Transaction transaction) {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  Row(
                    children: [
                      Text(
                        dateFormat.format(transaction.date),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Text('  •  ',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12)),
                      Flexible(
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: categoryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}
