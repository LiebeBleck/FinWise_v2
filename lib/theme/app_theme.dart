import 'package:flutter/material.dart';

/// Кастомная анимация переходов: fade + лёгкий слайд снизу вверх
class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    // Уходящий экран слегка затемняется
    final fadeOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeIn,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.92).animate(fadeOut),
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}

const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _FadeSlideTransitionsBuilder(),
    TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
    TargetPlatform.windows: _FadeSlideTransitionsBuilder(),
  },
);

class AppTheme {
  // Цвета из дизайн-системы
  static const Color primaryColor = Color(0xFFF97316); // Терракотовый
  static const Color successColor = Color(0xFF22C55E); // Зелёный
  static const Color errorColor = Color(0xFFEF4444); // Красный
  static const Color neutralColor = Color(0xFF6B7280); // Серый

  // Светлая тема
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: Colors.white,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1E1E1E),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E1E1E),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E1E1E),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF1E1E1E),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF1E1E1E),
        ),
      ),
    );
  }

  // Тёмная тема
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: Color(0xFF1E1E1E),
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFE0E0E0),
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE0E0E0),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE0E0E0),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFE0E0E0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFE0E0E0),
        ),
      ),
    );
  }
}
