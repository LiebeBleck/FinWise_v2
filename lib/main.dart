import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  runApp(const FinWiseApp());
}

class FinWiseApp extends StatelessWidget {
  const FinWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FinWise')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text('Добро пожаловать в FinWise!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('Умное приложение для учёта финансов', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скоро здесь появится онбординг! 🚀')),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Начать'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Скоро можно будет добавить транзакцию!')),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
