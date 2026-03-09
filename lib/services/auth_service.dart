import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/budget.dart';
import 'api_service.dart';
import 'data_sync_service.dart';

/// Сервис аутентификации с безопасным хранением паролей
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _passwordKey = 'user_password_hash';
  static const String _isLoggedInKey = 'user_is_logged_in';

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
        email: email,
        currency: currency,
        timezone: 'Europe/Moscow', // По умолчанию
        theme: 'light', // По умолчанию светлая тема
      );

      // Сохраняем (box хранит только одного пользователя - первого)
      await usersBox.clear();
      await usersBox.add(user);

      // Создаём начальный бюджет
      final budgetBox = Hive.box<Budget>('budget');
      final budget = Budget(
        monthlyAmount: monthlyBudget,
        periodStart: DateTime.now(),
      );
      await budgetBox.put('current', budget);

      // Помечаем пользователя как вошедшего
      await _storage.write(key: _isLoggedInKey, value: 'true');

      // Backend registration (fire-and-forget — работает и без интернета)
      _registerOnBackend(email: email, username: nickname, passwordHash: passwordHash, currency: currency);

      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  /// Регистрация на backend в фоне
  static void _registerOnBackend({
    required String email,
    required String username,
    required String passwordHash,
    required String currency,
  }) async {
    try {
      await ApiService.register(
        email: email,
        username: username,
        passwordHash: passwordHash,
        currency: currency,
      );
      // После регистрации — сразу push всех локальных данных
      DataSyncService.pushAllBackground();
    } catch (_) {
      // Нет интернета или аккаунт уже существует — пробуем войти
      try {
        await ApiService.login(email: email, passwordHash: passwordHash);
        DataSyncService.pushAllBackground();
      } catch (_) {
        // Backend недоступен — продолжаем работать локально
      }
    }
  }

  /// Вход пользователя (проверка email и пароля)
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      // Получаем пользователя
      final user = await getCurrentUser();
      if (user == null || user.email != email) {
        return false;
      }

      // Проверяем пароль
      final ok = await verifyPassword(password);
      if (ok) {
        // Помечаем как вошедшего
        await _storage.write(key: _isLoggedInKey, value: 'true');
        // Обновляем токен на backend в фоне
        _loginOnBackend(email: email, passwordHash: _hashPassword(password));
      }
      return ok;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Вход на backend в фоне + pull данных если токена ещё нет
  static void _loginOnBackend({
    required String email,
    required String passwordHash,
  }) async {
    try {
      final hadToken = await ApiService.hasToken();
      await ApiService.login(email: email, passwordHash: passwordHash);
      if (!hadToken) {
        // Первый вход с сервером — тянем данные (восстановление на новом устройстве)
        await DataSyncService.pullAll();
      } else {
        // Регулярный вход — push локальных данных
        DataSyncService.pushAllBackground();
      }
    } catch (_) {
      // Backend недоступен — работаем локально
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

  /// Проверка: вошёл ли пользователь в систему
  static Future<bool> isUserRegistered() async {
    try {
      final loggedIn = await _storage.read(key: _isLoggedInKey);
      return loggedIn == 'true';
    } catch (e) {
      print('Check login state error: $e');
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

  /// Выход — сбрасывает сессию, но сохраняет данные пользователя для повторного входа
  static Future<void> logout() async {
    try {
      await _storage.write(key: _isLoggedInKey, value: 'false');
      await ApiService.clearToken();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Получить SHA-256 хэш пароля (для использования как credential к backend)
  static Future<String?> getPasswordHash() =>
      _storage.read(key: _passwordKey);

  /// Хэширование пароля с помощью SHA-256
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
