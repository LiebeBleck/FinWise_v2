import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/hive_service.dart';
import 'services/auth_service.dart';
import 'utils/migrate_dates.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (also initializes default categories)
  await HiveService.init();

  // Run data migrations (if needed)
  await checkAndMigrate();

  // Initialize date formatting for Russian locale
  await initializeDateFormatting('ru_RU', null);

  runApp(const FinWiseApp());
}

class FinWiseApp extends StatefulWidget {
  const FinWiseApp({super.key});

  @override
  State<FinWiseApp> createState() => _FinWiseAppState();
}

class _FinWiseAppState extends State<FinWiseApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _themeMode = user?.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const StartupScreen(),
    );
  }
}

/// Экран загрузки - определяет куда перенаправить пользователя
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Небольшая задержка для показа splash (опционально)
    await Future.delayed(const Duration(milliseconds: 500));

    // Проверяем: зарегистрирован ли пользователь
    final isRegistered = await AuthService.isUserRegistered();

    if (!mounted) return;

    // Перенаправляем на соответствующий экран
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            isRegistered ? const MainScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
