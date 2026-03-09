String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Введите пароль';
  if (value.length < 8) return 'Минимум 8 символов';
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Нужна заглавная буква (A-Z)';
  if (!RegExp(r'[a-z]').hasMatch(value)) return 'Нужна строчная буква (a-z)';
  if (!RegExp(r'[0-9]').hasMatch(value)) return 'Нужна цифра (0-9)';
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Нужен спецсимвол (!@#\$%...)';
  }
  return null;
}
