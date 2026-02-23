import 'package:flutter/material.dart';

/// Global theme notifier — изменение здесь мгновенно применяет тему
/// без перезапуска приложения.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
