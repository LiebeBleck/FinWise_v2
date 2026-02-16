import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';
import '../services/export_import_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/budget.dart';

/// Экран профиля и настроек
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  Budget? _currentBudget;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = await AuthService.getCurrentUser();
    final budgetsBox = await Hive.openBox<Budget>('budgets');
    if (budgetsBox.isNotEmpty) {
      _currentBudget = budgetsBox.values.first;
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final result = await ExportImportService.exportToJSON();

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Экспорт завершён!\n'
              'Транзакций: ${result.transactionsCount}\n'
              'Категорий: ${result.categoriesCount}\n'
              'Бюджетов: ${result.budgetsCount}\n\n'
              'Файл сохранён: ${result.filePath}',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка экспорта: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Импорт данных'),
        content: const Text(
          'Импорт добавит данные из файла к существующим.\n\n'
          'Дубликаты транзакций будут пропущены.\n\n'
          'Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImporting = true);

    try {
      final result = await ExportImportService.importFromJSON();

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Импорт завершён!\n'
              'Транзакций: ${result.transactionsCount}\n'
              'Категорий: ${result.categoriesCount}\n'
              'Бюджетов: ${result.budgetsCount}',
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handleChangeCurrency() async {
    if (_currentUser == null) return;

    final newCurrency = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбор валюты'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCurrencyOption('₽', 'Рубль'),
            _buildCurrencyOption('\$', 'Доллар'),
            _buildCurrencyOption('€', 'Евро'),
            _buildCurrencyOption('£', 'Фунт'),
          ],
        ),
      ),
    );

    if (newCurrency == null || newCurrency == _currentUser!.currency) return;

    _currentUser!.currency = newCurrency;
    await AuthService.updateUser(_currentUser!);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Валюта изменена на $newCurrency')),
      );
    }
  }

  Widget _buildCurrencyOption(String currency, String name) {
    return ListTile(
      title: Text('$currency $name'),
      onTap: () => Navigator.pop(context, currency),
    );
  }

  Future<void> _handleChangeBudget() async {
    if (_currentBudget == null) return;

    final controller = TextEditingController(
      text: _currentBudget!.monthlyAmount.toStringAsFixed(0),
    );

    final newAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить бюджет'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Месячный бюджет',
            suffix: Text(_currentUser?.currency ?? '₽'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              Navigator.pop(context, amount);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (newAmount == null || newAmount <= 0) return;

    _currentBudget!.monthlyAmount = newAmount;
    await _currentBudget!.save();
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бюджет обновлён')),
      );
    }
  }

  Future<void> _handleToggleTheme(bool isDark) async {
    if (_currentUser == null) return;

    _currentUser!.theme = isDark ? 'dark' : 'light';
    await AuthService.updateUser(_currentUser!);

    if (mounted) {
      // Перезапуск приложения для применения темы
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тема изменена. Перезапустите приложение для применения.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() {});
  }

  Future<void> _handleChangePassword() async {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Смена пароля'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Старый пароль'),
                validator: (v) => v == null || v.isEmpty ? 'Введите старый пароль' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите новый пароль';
                  if (v.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Подтверждение'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Подтвердите пароль';
                  if (v != newPasswordController.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final success = await AuthService.changePassword(
                oldPassword: oldPasswordController.text,
                newPassword: newPasswordController.text,
              );

              if (context.mounted) Navigator.pop(context, success);
            },
            child: const Text('Изменить'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Пароль успешно изменён'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Неверный старый пароль'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Аватар и имя
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser?.username ?? 'Пользователь',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Секция: Настройки
          const Text(
            'Настройки',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monetization_on),
                  title: const Text('Валюта'),
                  subtitle: Text(_currentUser?.currency ?? '₽'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleChangeCurrency,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Месячный бюджет'),
                  subtitle: Text(
                    '${_currentBudget?.monthlyAmount.toStringAsFixed(0) ?? '0'} ${_currentUser?.currency ?? '₽'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handleChangeBudget,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('Тёмная тема'),
                  subtitle: const Text('Перезапустите после изменения'),
                  value: _currentUser?.theme == 'dark',
                  onChanged: _handleToggleTheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Секция: Безопасность
          const Text(
            'Безопасность',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Сменить пароль'),
              subtitle: const Text('Изменить пароль для входа'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _handleChangePassword,
            ),
          ),

          const SizedBox(height: 24),

          // Секция: Резервное копирование
          const Text(
            'Резервное копирование',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.upload_file,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('Экспорт данных'),
                  subtitle: const Text('Сохранить все данные в JSON файл'),
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExporting ? null : _handleExport,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.download,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('Импорт данных'),
                  subtitle: const Text('Восстановить данные из JSON файла'),
                  trailing: _isImporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isImporting ? null : _handleImport,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Информация
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'О резервном копировании',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Экспорт сохраняет все транзакции, категории и бюджеты\n'
                    '• Файл сохраняется в папку "Документы"\n'
                    '• Импорт не удаляет существующие данные\n'
                    '• Дубликаты автоматически пропускаются',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
