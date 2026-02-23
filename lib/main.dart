import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/hive_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'utils/migrate_dates.dart';
import 'utils/theme_notifier.dart';
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

  // Load saved theme before showing UI
  final user = await AuthService.getCurrentUser();
  themeNotifier.value =
      user?.theme == 'dark' ? ThemeMode.dark : ThemeMode.light;

  runApp(const FinWiseApp());
}

class FinWiseApp extends StatelessWidget {
  const FinWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'FinWise',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
