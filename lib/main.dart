import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/hive_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'utils/migrate_dates.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (also initializes default categories)
  await HiveService.init();

  // Run data migrations (if needed)
  await checkAndMigrate();

  // Initialize date formatting for Russian locale
  await initializeDateFormatting('ru_RU', null);

  // Initialize notifications
  await NotificationService.init();

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
      home: const SplashScreen(),
    );
  }
}
