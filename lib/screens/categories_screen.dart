import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── CRUD ──────────────────────────────────────────────

  int _getNextId() {
    final box = Hive.box<Category>('categories');
    if (box.isEmpty) return 100;
    final maxKey = box.keys.fold<int>(0, (max, key) {
      final k = key as int;
      return k > max ? k : max;
    });
    return maxKey + 1;
  }

  Future<void> _addCategory(
      String name, String color, String type) async {
    final box = Hive.box<Category>('categories');
    final id = _getNextId();
    final cat = Category(
      id: id,
      name: name,
      color: color,
      isDefault: false,
      type: type,
    );
    await box.put(id, cat);
  }

  Future<void> _editCategory(
      Category cat, String name, String color, String type) async {
    cat.name = name;
    cat.color = color;
    cat.type = type;
    await cat.save();
  }

  Future<void> _deleteCategory(Category cat) async {
    // Move transactions to "Прочее" (id=19)
    final txBox = Hive.box<Transaction>('transactions');
    for (final tx in txBox.values.where((t) => t.categoryId == cat.id)) {
      tx.categoryId = 19;
      await tx.save();
    }
    await Hive.box<Category>('categories').delete(cat.id);
  }

  // ── Dialogs ───────────────────────────────────────────

  Future<void> _showAddEditDialog({Category? category}) async {
    final nameController =
        TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.color ?? '#F97316';
    String selectedType = category?.type ?? 'expense';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  category == null
                      ? 'Новая категория'
                      : 'Редактировать категорию',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    hintText: 'Например: Домашние животные',
                    filled: true,
                    fillColor: const Color(0xFFFFF7ED),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.label_outline,
                        color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),

                // Type selector
                const Text(
                  'Тип категории',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _typeChip('Расходы', 'expense', selectedType, (v) {
                      setModal(() => selectedType = v);
                    }),
                    const SizedBox(width: 8),
                    _typeChip('Доходы', 'income', selectedType, (v) {
                      setModal(() => selectedType = v);
                    }),
                    const SizedBox(width: 8),
                    _typeChip('Оба', 'both', selectedType, (v) {
                      setModal(() => selectedType = v);
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Color picker
                const Text(
                  'Цвет',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                _buildColorPicker(selectedColor, (c) {
                  setModal(() => selectedColor = c);
                }),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Введите название категории')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      if (category == null) {
                        await _addCategory(name, selectedColor, selectedType);
                      } else {
                        await _editCategory(
                            category, name, selectedColor, selectedType);
                      }
                      if (mounted) setState(() {});
                    },
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
                      'Сохранить',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmDelete(Category cat) async {
    final txCount = Hive.box<Transaction>('transactions')
        .values
        .where((t) => t.categoryId == cat.id)
        .length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить категорию?'),
        content: Text(
          txCount > 0
              ? 'Категория "${cat.name}" используется в $txCount транзакц${_txSuffix(txCount)}. '
                  'Они будут перемещены в "Прочее".'
              : 'Категория "${cat.name}" будет удалена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteCategory(cat);
      if (mounted) setState(() {});
    }
  }

  String _txSuffix(int count) {
    if (count % 10 == 1 && count % 100 != 11) { return 'ии'; }
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) { return 'иях'; }
    return 'иях';
  }

  // ── UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildHeader(context),
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Расходы'),
                Tab(text: 'Доходы'),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable:
                  Hive.box<Category>('categories').listenable(),
              builder: (context, Box<Category> box, _) {
                final categories = box.values.toList();
                final expenses = categories
                    .where((c) => c.type == 'expense' || c.type == 'both')
                    .toList()
                  ..sort((a, b) {
                    if (a.isDefault != b.isDefault) {
                      return a.isDefault ? -1 : 1;
                    }
                    return a.name.compareTo(b.name);
                  });
                final incomes = categories
                    .where((c) => c.type == 'income' || c.type == 'both')
                    .toList()
                  ..sort((a, b) {
                    if (a.isDefault != b.isDefault) {
                      return a.isDefault ? -1 : 1;
                    }
                    return a.name.compareTo(b.name);
                  });

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCategoryList(expenses),
                    _buildCategoryList(incomes),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
        elevation: 4,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 8,
        right: 20,
        bottom: 16,
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
              'Категории',
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

  Widget _buildCategoryList(List<Category> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Нет категорий',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 8),
            Text('Нажмите "+" чтобы добавить',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    // Separate default and custom
    final defaults = categories.where((c) => c.isDefault).toList();
    final custom = categories.where((c) => !c.isDefault).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (custom.isNotEmpty) ...[
          _sectionHeader('Мои категории', custom.length),
          const SizedBox(height: 8),
          ...custom.map((cat) => _buildCategoryTile(cat, isCustom: true)),
          const SizedBox(height: 16),
        ],
        _sectionHeader('Стандартные', defaults.length),
        const SizedBox(height: 8),
        ...defaults.map((cat) => _buildCategoryTile(cat, isCustom: false)),
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Category cat, {required bool isCustom}) {
    Color catColor;
    try {
      catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      catColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: catColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        title: Text(
          cat.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _typeName(cat.type),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: isCustom
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: AppTheme.primaryColor),
                    onPressed: () =>
                        _showAddEditDialog(category: cat),
                    tooltip: 'Редактировать',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    onPressed: () => _confirmDelete(cat),
                    tooltip: 'Удалить',
                  ),
                ],
              )
            : const Icon(Icons.lock_outline,
                size: 18, color: Colors.grey),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  String _typeName(String type) {
    switch (type) {
      case 'income':
        return 'Доход';
      case 'expense':
        return 'Расход';
      case 'both':
        return 'Доход и расход';
      default:
        return type;
    }
  }

  Widget _typeChip(
      String label, String value, String selected, Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker(
      String selectedColor, Function(String) onColorSelected) {
    const colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFC107', '#FF9800', '#FF5722', '#795548',
      '#607D8B', '#9E9E9E', '#F97316', '#6366F1',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        Color c;
        try {
          c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        } catch (_) {
          c = Colors.grey;
        }
        final isSelected = selectedColor == hex;
        return GestureDetector(
          onTap: () => onColorSelected(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
