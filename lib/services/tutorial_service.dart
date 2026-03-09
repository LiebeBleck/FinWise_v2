import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Управление состоянием обучающего туториала.
/// Хранит флаги shown/not-shown в SharedPreferences.
class TutorialService {
  static const String _homeShownKey = 'tutorial_home_shown';

  /// Уведомитель для немедленного запуска туториала (без перезапуска экрана)
  static final ValueNotifier<bool> showTutorialNow = ValueNotifier(false);

  /// Callback для переключения на вкладку "Главная" (устанавливается MainScreen)
  static VoidCallback? switchToHomeCallback;

  /// Нужно ли показать туториал на HomeScreen?
  static Future<bool> shouldShowHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_homeShownKey) ?? false);
  }

  /// Пометить туториал HomeScreen как показанный
  static Future<void> markHomeTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeShownKey, true);
  }

  /// Сбросить все туториалы (для кнопки "Показать обучение" в ProfileScreen)
  static Future<void> resetTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeShownKey);
  }
}
