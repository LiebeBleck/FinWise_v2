import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';

/// Экран входа/регистрации
class RegistrationScreen extends StatefulWidget {
  final bool isLogin; // true = вход, false = регистрация

  const RegistrationScreen({
    super.key,
    required this.isLogin,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _budgetController = TextEditingController(text: '50000');

  String _selectedCurrency = '₽';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool success;

      if (widget.isLogin) {
        // Вход
        success = await AuthService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Регистрация
        success = await AuthService.register(
          email: _emailController.text.trim(),
          nickname: _nicknameController.text.trim(),
          password: _passwordController.text,
          currency: _selectedCurrency,
          monthlyBudget: double.tryParse(_budgetController.text) ?? 50000,
        );
      }

      if (!mounted) return;

      if (success) {
        // Переход на главный экран
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isLogin
                  ? 'Неверный email или пароль'
                  : 'Ошибка регистрации. Попробуйте снова.',
            ),
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
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
              // Верхняя часть с заголовком
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isLogin ? 'Добро пожаловать' : 'Создать аккаунт',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Нижняя часть с формой
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email
                          _buildTextField(
                            controller: _emailController,
                            label: widget.isLogin
                                ? 'Email'
                                : 'Email',
                            hint: 'example@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите email';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Неверный формат email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Никнейм (только для регистрации)
                          if (!widget.isLogin) ...[
                            _buildTextField(
                              controller: _nicknameController,
                              label: 'Полное имя',
                              hint: 'Ваше имя',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите имя';
                                }
                                if (value.length < 2) {
                                  return 'Минимум 2 символа';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Пароль
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Пароль',
                            hint: 'Минимум 6 символов',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите пароль';
                              }
                              if (value.length < 6) {
                                return 'Минимум 6 символов';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Подтверждение пароля (только для регистрации)
                          if (!widget.isLogin) ...[
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Подтверждение пароля',
                              hint: 'Повторите пароль',
                              icon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword =
                                      !_obscureConfirmPassword);
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Подтвердите пароль';
                                }
                                if (value != _passwordController.text) {
                                  return 'Пароли не совпадают';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // "Забыли пароль?" (только для входа)
                          if (widget.isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: Реализовать восстановление пароля
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Восстановление пароля пока не реализовано'),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Забыли пароль?',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Начальные настройки (только для регистрации)
                          if (!widget.isLogin) ...[
                            const Divider(height: 32),
                            const Text(
                              'Начальные настройки',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Валюта
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCurrency,
                              decoration: InputDecoration(
                                labelText: 'Валюта',
                                prefixIcon: const Icon(Icons.monetization_on_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                              ),
                              items: const [
                                DropdownMenuItem(value: '₽', child: Text('₽ Рубль')),
                                DropdownMenuItem(
                                    value: '\$', child: Text('\$ Доллар')),
                                DropdownMenuItem(value: '€', child: Text('€ Евро')),
                                DropdownMenuItem(value: '£', child: Text('£ Фунт')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCurrency = value!);
                              },
                            ),

                            const SizedBox(height: 16),

                            // Месячный бюджет
                            _buildTextField(
                              controller: _budgetController,
                              label: 'Месячный бюджет',
                              hint: '50000',
                              icon: Icons.account_balance_wallet_outlined,
                              keyboardType: TextInputType.number,
                              suffix: Text(_selectedCurrency),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите бюджет';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null || amount <= 0) {
                                  return 'Введите корректную сумму';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          const SizedBox(height: 8),

                          // Кнопка входа/регистрации
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
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
                                  : Text(
                                      widget.isLogin ? 'Войти' : 'Создать аккаунт',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Переход на другой экран
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.isLogin
                                    ? 'Нет аккаунта?'
                                    : 'Уже есть аккаунт?',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RegistrationScreen(
                                        isLogin: !widget.isLogin,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  widget.isLogin ? 'Регистрация' : 'Войти',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Политика конфиденциальности (только для регистрации)
                          if (!widget.isLogin) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                height: 1.5,
                              ),
                            ),
                          ],
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

  /// Создаёт кастомное текстовое поле
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
      ),
      validator: validator,
    );
  }
}
