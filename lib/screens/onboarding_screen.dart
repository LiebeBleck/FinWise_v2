import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'registration_screen.dart';

/// Экран онбординга (приветствие при первом запуске)
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Логотип/иконка
              Icon(
                Icons.account_balance_wallet,
                size: 100,
                color: AppTheme.primaryColor,
              ),

              const SizedBox(height: 32),

              // Название приложения
              const Text(
                'FinWise',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Подзаголовок
              Text(
                'Умное управление финансами',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 48),

              // Возможности
              _buildFeature(
                Icons.receipt_long,
                'Сканирование чеков',
                'QR-коды и OCR распознавание',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                Icons.auto_awesome,
                'ML категоризация',
                'Автоматическое определение категорий с точностью 88%',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                Icons.bar_chart,
                'Аналитика и советы',
                'Графики, прогнозы, персональные рекомендации',
              ),
              const SizedBox(height: 16),
              _buildFeature(
                Icons.cloud_off,
                'Офлайн режим',
                'Работает без интернета, данные хранятся локально',
              ),

              const Spacer(),

              // Кнопка начала
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistrationScreen(isLogin: false),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Начать',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
