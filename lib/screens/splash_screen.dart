import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'main_screen.dart';

/// Splash screen с анимацией логотипа
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Настройка анимации
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Fade анимация (появление)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    // Scale анимация (увеличение)
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    ));

    // Запуск анимации
    _animationController.forward();

    // Навигация после задержки
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Ждём завершения анимации
    await Future.delayed(const Duration(milliseconds: 2500));

    // Проверяем статус аутентификации
    final isRegistered = await AuthService.isUserRegistered();

    if (!mounted) return;

    // Навигация на соответствующий экран
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isRegistered ? const MainScreen() : const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFFD97706), // Тёмный терракотовый
                    const Color(0xFFF97316), // Основной терракотовый
                  ]
                : [
                    const Color(0xFFF97316), // Терракотовый (основной цвет)
                    const Color(0xFFFB923C), // Светлый терракотовый
                  ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Логотип
                      _buildLogo(),
                      const SizedBox(height: 24),
                      // Название приложения
                      const Text(
                        'FinWise',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Создаёт иконку логотипа (график роста со стрелкой)
  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          // График (столбцы)
          Positioned(
            left: 20,
            bottom: 25,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(height: 20),
                const SizedBox(width: 6),
                _buildBar(height: 30),
                const SizedBox(width: 6),
                _buildBar(height: 45),
                const SizedBox(width: 6),
                _buildBar(height: 35),
              ],
            ),
          ),
          // Стрелка вверх
          Positioned(
            right: 15,
            top: 15,
            child: Transform.rotate(
              angle: -0.5,
              child: const Icon(
                Icons.trending_up,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Создаёт один столбец графика
  Widget _buildBar({required double height}) {
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
