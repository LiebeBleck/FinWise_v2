import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String currency; // RUB, USD, EUR и т.д.

  @HiveField(2)
  String timezone; // Europe/Moscow, UTC и т.д.

  @HiveField(3)
  String theme; // 'light' или 'dark'

  @HiveField(4)
  String? email;

  User({
    required this.username,
    this.currency = 'RUB',
    this.timezone = 'Europe/Moscow',
    this.theme = 'light',
    this.email,
  });
}
