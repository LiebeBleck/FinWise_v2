import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/budget.dart';

/// Сервис аутентификации с безопасным хранением паролей
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _passwordKey = 'user_password_hash';

  /// Регистрация нового пользователя
  static Future<bool> register({
    required String email,
    required String nickname,
    required String password,
    required String currency,
    required double monthlyBudget,
  }) async {
    try {
      // Хэшируем пароль (SHA-256)
      final passwordHash = _hashPassword(password);

      // Сохраняем хэш в secure storage
      await _storage.write(key: _passwordKey, value: passwordHash);

      // Создаём пользователя в Hive
      final usersBox = await Hive.openBox<User>('users');
      final user = User(
        username: nickname,
        currency: currency,
        timezone: 'Europe/Moscow', // По умолчанию
        theme: 'light', // По умолчанию светлая тема
      );

      // Сохраняем (box хранит только одного пользователя - первого)
      await usersBox.clear();
      await usersBox.add(user);

      // Создаём начальный бюджет
      final budgetsBox = await Hive.openBox<Budget>('budgets');
      await budgetsBox.clear();
      final budget = Budget(
        monthlyAmount: monthlyBudget,
        periodStart: DateTime.now(),
      );
      await budgetsBox.add(budget);

      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  /// Проверка пароля (для входа или смены)
  static Future<bool> verifyPassword(String password) async {
    try {
      final storedHash = await _storage.read(key: _passwordKey);
      if (storedHash == null) return false;

      final inputHash = _hashPassword(password);
      return storedHash == inputHash;
    } catch (e) {
      print('Password verification error: $e');
      return false;
    }
  }

  /// Смена пароля
  static Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // Проверяем старый пароль
      final isOldValid = await verifyPassword(oldPassword);
      if (!isOldValid) return false;

      // Хэшируем и сохраняем новый
      final newHash = _hashPassword(newPassword);
      await _storage.write(key: _passwordKey, value: newHash);

      return true;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }

  /// Проверка: зарегистрирован ли пользователь
  static Future<bool> isUserRegistered() async {
    try {
      final usersBox = await Hive.openBox<User>('users');
      final hasPassword = await _storage.read(key: _passwordKey) != null;

      return usersBox.isNotEmpty && hasPassword;
    } catch (e) {
      print('Check registration error: $e');
      return false;
    }
  }

  /// Получить текущего пользователя
  static Future<User?> getCurrentUser() async {
    try {
      final usersBox = await Hive.openBox<User>('users');
      if (usersBox.isEmpty) return null;

      return usersBox.values.first;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  /// Обновить данные пользователя
  static Future<bool> updateUser(User user) async {
    try {
      final usersBox = await Hive.openBox<User>('users');
      await usersBox.clear();
      await usersBox.add(user);
      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  /// Выход (сброс всех данных) - для тестирования
  static Future<void> logout() async {
    try {
      await _storage.delete(key: _passwordKey);
      final usersBox = await Hive.openBox<User>('users');
      await usersBox.clear();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Хэширование пароля с помощью SHA-256
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
