import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/budget.dart';
import '../services/export_import_service.dart';

/// Экран редактирования профиля в современном стиле
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  User? _currentUser;
  Budget? _currentBudget;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _budgetController;

  String _selectedCurrency = '₽';
  bool _pushNotifications = false;
  bool _darkTheme = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _budgetController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    _currentUser = await AuthService.getCurrentUser();
    final budgetsBox = await Hive.openBox<Budget>('budgets');
    if (budgetsBox.isNotEmpty) {
      _currentBudget = budgetsBox.values.first;
    }

    if (_currentUser != null) {
      _usernameController.text = _currentUser!.username;
      _emailController.text = _currentUser!.email ?? '';
      _selectedCurrency = _currentUser!.currency;
      _darkTheme = _currentUser!.theme == 'dark';
      _budgetController.text = _currentBudget?.monthlyAmount.toStringAsFixed(0) ?? '50000';
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Обновляем пользователя
      if (_currentUser != null) {
        _currentUser!.username = _usernameController.text.trim();
        _currentUser!.email = _emailController.text.trim();
        _currentUser!.currency = _selectedCurrency;
        _currentUser!.theme = _darkTheme ? 'dark' : 'light';

        await AuthService.updateUser(_currentUser!);
      }

      // Обновляем бюджет
      if (_currentBudget != null) {
        final newAmount = double.tryParse(_budgetController.text);
        if (newAmount != null && newAmount > 0) {
          _currentBudget!.monthlyAmount = newAmount;
          await _currentBudget!.save();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль успешно обновлён'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);

    try {
      final result = await ExportImportService.exportToJSON();

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Экспорт завершён!\n'
              'Транзакций: ${result.transactionsCount}\n'
              'Файл: ${result.filePath}',
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Импорт данных'),
        content: const Text('Импорт добавит данные из файла к существующим. Продолжить?'),
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

    setState(() => _isLoading = true);

    try {
      final result = await ExportImportService.importFromJSON();

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Импорт завершён!\n'
              'Транзакций: ${result.transactionsCount}',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _currentUser?.email?.hashCode.abs().toString().padLeft(8, '0').substring(0, 8) ?? '00000000';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, 0.25),
            colors: isDark
                ? [
                    const Color(0xFFD97706),
                    const Color(0xFF1E1E1E),
                  ]
                : [
                    AppTheme.primaryColor,
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Text(
                      'Edit My Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Основная карточка с контентом
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8F5E9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Аватар с кнопкой редактирования
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 45,
                                    backgroundColor: Colors.grey[300],
                                    child: Icon(
                                      Icons.person,
                                      size: 45,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8F5E9),
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Имя и ID
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _currentUser?.username ?? 'Пользователь',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $userId',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Account Settings
                          Text(
                            'Account Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Username
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.person_outline,
                            isDark: isDark,
                            validator: (v) => v == null || v.isEmpty ? 'Введите имя' : null,
                          ),

                          const SizedBox(height: 16),

                          // Email
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            isDark: isDark,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите email';
                              if (!v.contains('@')) return 'Неверный формат email';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Monthly Budget
                          _buildTextField(
                            controller: _budgetController,
                            label: 'Monthly Budget',
                            icon: Icons.account_balance_wallet_outlined,
                            suffix: Text(_selectedCurrency),
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Введите бюджет';
                              final amount = double.tryParse(v);
                              if (amount == null || amount <= 0) return 'Некорректная сумма';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Currency
                          _buildDropdown(
                            label: 'Currency',
                            value: _selectedCurrency,
                            items: const ['₽', '\$', '€', '£'],
                            icon: Icons.monetization_on_outlined,
                            isDark: isDark,
                            onChanged: (v) => setState(() => _selectedCurrency = v!),
                          ),

                          const SizedBox(height: 24),

                          // Toggles
                          _buildToggleTile(
                            title: 'Push Notifications',
                            value: _pushNotifications,
                            isDark: isDark,
                            onChanged: (v) => setState(() => _pushNotifications = v),
                          ),

                          const SizedBox(height: 12),

                          _buildToggleTile(
                            title: 'Turn Dark Theme',
                            value: _darkTheme,
                            isDark: isDark,
                            onChanged: (v) => setState(() => _darkTheme = v),
                          ),

                          const SizedBox(height: 32),

                          // Update Profile Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleUpdateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Update Profile',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Additional options
                          _buildAdditionalOptions(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        suffix: suffix,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required bool isDark,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        filled: true,
        fillColor: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required bool isDark,
    required void Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Change Password
        ListTile(
          leading: Icon(Icons.lock_outline, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          title: Text(
            'Change Password',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          onTap: _handleChangePassword,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        ),

        const SizedBox(height: 12),

        // Export Data
        ListTile(
          leading: Icon(Icons.upload_file, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          title: Text(
            'Export Data',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          onTap: _handleExport,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        ),

        const SizedBox(height: 12),

        // Import Data
        ListTile(
          leading: Icon(Icons.download, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          title: Text(
            'Import Data',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          onTap: _handleImport,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: isDark ? Colors.grey[850] : const Color(0xFFC8E6C9),
        ),
      ],
    );
  }
}
