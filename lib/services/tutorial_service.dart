import 'package:shared_preferences/shared_preferences.dart';

/// Управление состоянием обучающего туториала.
/// Хранит флаги shown/not-shown в SharedPreferences.
class TutorialService {
  static const String _homeShownKey = 'tutorial_home_shown';

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
