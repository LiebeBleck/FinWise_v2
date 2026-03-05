import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Результат авторизации на сервере
class ApiAuthResult {
  final String token;
  final String userId;
  final String username;
  final String email;
  ApiAuthResult({
    required this.token,
    required this.userId,
    required this.username,
    required this.email,
  });

  factory ApiAuthResult.fromJson(Map<String, dynamic> j) => ApiAuthResult(
        token: j['token'] as String,
        userId: j['user_id'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
      );
}

/// HTTP-клиент для FinWise backend.
/// Хранит JWT-токен в flutter_secure_storage под ключом 'sync_token'.
class ApiService {
  static const _base = 'http://80.93.60.208/api/v1';
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'sync_token';
  static const _timeout = Duration(seconds: 15);

  // ── Token management ────────────────────────────────────

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey)) != null;

  // ── Auth ────────────────────────────────────────────────

  /// Регистрация. passwordHash = SHA-256 hex пароля (из AuthService).
  static Future<ApiAuthResult> register({
    required String email,
    required String username,
    required String passwordHash,
    String currency = 'RUB',
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'username': username,
            'password_hash': passwordHash,
            'currency': currency,
          }),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final result = ApiAuthResult.fromJson(jsonDecode(resp.body));
      await saveToken(result.token);
      return result;
    }
    throw _apiError(resp);
  }

  /// Вход в аккаунт.
  static Future<ApiAuthResult> login({
    required String email,
    required String passwordHash,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password_hash': passwordHash,
          }),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200) {
      final result = ApiAuthResult.fromJson(jsonDecode(resp.body));
      await saveToken(result.token);
      return result;
    }
    throw _apiError(resp);
  }

  // ── Sync ────────────────────────────────────────────────

  /// Push всех данных на сервер. Бросает исключение при ошибке.
  static Future<void> pushData(Map<String, dynamic> payload) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final resp = await http
        .post(
          Uri.parse('$_base/sync/push'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200) throw _apiError(resp);
  }

  /// Pull всех данных с сервера. Возвращает JSON.
  static Future<Map<String, dynamic>> pullData() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final resp = await http
        .get(
          Uri.parse('$_base/sync/pull'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw _apiError(resp);
  }

  // ── Helper ──────────────────────────────────────────────

  static Exception _apiError(http.Response resp) {
    String detail = 'Server error ${resp.statusCode}';
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body.containsKey('detail')) {
        detail = body['detail'].toString();
      }
    } catch (_) {}
    return Exception(detail);
  }
}
