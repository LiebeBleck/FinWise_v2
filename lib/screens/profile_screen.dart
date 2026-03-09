import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';
import '../services/api_service.dart';
import '../services/data_sync_service.dart';
import '../utils/responsive_helper.dart';
import '../models/user.dart';
import 'edit_profile_screen.dart';
import 'categories_screen.dart';
import 'budget_screen.dart';
import 'savings_goals_screen.dart';
import 'registration_screen.dart';

/// Современный экран профиля в стиле дизайна
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = await AuthService.getCurrentUser();
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы действительно хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationScreen(isLogin: true),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showSyncSheet(BuildContext context) async {
    final hasToken = await ApiService.hasToken();
    final status = DataSyncService.status;
    final lastSync = DataSyncService.lastSyncAt;
    final lastError = DataSyncService.lastError;

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SyncSheet(
        hasToken: hasToken,
        status: status,
        lastSyncAt: lastSync,
        lastError: lastError,
        onPushNow: () async {
          Navigator.pop(ctx);
          final ok = await DataSyncService.pushAll();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? '✅ Данные успешно синхронизированы' : '❌ Ошибка синхронизации'),
            duration: const Duration(seconds: 2),
          ));
        },
        onPullNow: () async {
          Navigator.pop(ctx);
          final ok = await DataSyncService.pullAll();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? '✅ Данные восстановлены с сервера' : '❌ Ошибка загрузки данных'),
            duration: const Duration(seconds: 2),
          ));
        },
      ),
    );
  }

  void _handleEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    ).then((_) => _loadUserData());
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - скоро будет доступно'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Генерируем ID из username (первые 8 символов email hash)
    final userId = _currentUser?.email?.hashCode.abs().toString().padLeft(8, '0').substring(0, 8) ?? '00000000';

    return Scaffold(
      body: ResponsiveHelper.constrain(Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, 0.3),
            colors: isDark
                ? [
                    const Color(0xFFD97706),
                    const Color(0xFF1E1E1E),
                  ]
                : [
                    AppTheme.primaryColor,
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Text(
                      'Профиль',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Основная карточка с контентом
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFF7ED),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Аватар
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: _currentUser?.profilePhotoPath != null
                                    ? FileImage(File(_currentUser!.profilePhotoPath!))
                                    : null,
                                child: _currentUser?.profilePhotoPath == null
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[600],
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Имя пользователя
                        Text(
                          _currentUser?.username ?? 'Пользователь',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ID
                        Text(
                          'ID: $userId',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Меню опций
                        _buildMenuCard(
                          isDark: isDark,
                          items: [
                            _MenuItem(
                              icon: Icons.person_outline,
                              iconColor: AppTheme.primaryColor,
                              title: 'Редактировать профиль',
                              onTap: _handleEditProfile,
                            ),
                            _MenuItem(
                              icon: Icons.category_outlined,
                              iconColor: AppTheme.primaryColor,
                              title: 'Категории',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CategoriesScreen(),
                                  ),
                                );
                              },
                            ),
                            _MenuItem(
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: AppTheme.primaryColor,
                              title: 'Бюджеты',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BudgetScreen(),
                                  ),
                                );
                              },
                            ),
                            _MenuItem(
                              icon: Icons.savings_outlined,
                              iconColor: AppTheme.primaryColor,
                              title: 'Цели сбережений',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SavingsGoalsScreen(),
                                  ),
                                );
                              },
                            ),
                            _MenuItem(
                              icon: Icons.cloud_sync_outlined,
                              iconColor: const Color(0xFF2196F3),
                              title: 'Синхронизация с облаком',
                              onTap: () => _showSyncSheet(context),
                            ),
                            _MenuItem(
                              icon: Icons.school_outlined,
                              iconColor: AppTheme.primaryColor,
                              title: 'Показать обучение',
                              onTap: () async {
                                await TutorialService.resetTutorials();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Откройте "Главная" для просмотра обучения'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            _MenuItem(
                              icon: Icons.shield_outlined,
                              iconColor: AppTheme.primaryColor,
                              title: 'Безопасность',
                              onTap: () => _showComingSoon('Безопасность'),
                            ),
                            _MenuItem(
                              icon: Icons.help_outline,
                              iconColor: AppTheme.primaryColor,
                              title: 'Помощь',
                              onTap: () => _showComingSoon('Помощь'),
                            ),
                            _MenuItem(
                              icon: Icons.logout,
                              iconColor: AppTheme.primaryColor,
                              title: 'Выйти',
                              onTap: _handleLogout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildMenuCard({
    required bool isDark,
    required List<_MenuItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 20,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });
}

// ── Sync bottom sheet ──────────────────────────────────────

class _SyncSheet extends StatelessWidget {
  final bool hasToken;
  final SyncStatus status;
  final DateTime? lastSyncAt;
  final String? lastError;
  final VoidCallback onPushNow;
  final VoidCallback onPullNow;

  const _SyncSheet({
    required this.hasToken,
    required this.status,
    required this.lastSyncAt,
    required this.lastError,
    required this.onPushNow,
    required this.onPullNow,
  });

  @override
  Widget build(BuildContext context) {
    final connected = hasToken;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title + status
          Row(
            children: [
              const Text('Синхронизация с облаком',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF22C55E).withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0xFF22C55E)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      connected ? 'Подключено' : 'Не подключено',
                      style: TextStyle(
                        fontSize: 12,
                        color: connected
                            ? const Color(0xFF16A34A)
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Last sync info
          if (lastSyncAt != null)
            Text(
              'Последняя синхронизация: ${_formatDt(lastSyncAt!)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            )
          else if (!connected)
            Text(
              'Данные синхронизируются автоматически при входе в аккаунт',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),

          // Error
          if (lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ошибка: $lastError',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),

          const SizedBox(height: 20),

          // Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: connected ? onPushNow : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Отправить данные на сервер'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: connected ? onPullNow : null,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Восстановить данные с сервера'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                side: BorderSide(
                    color: connected
                        ? const Color(0xFF2196F3)
                        : Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Данные хранятся на сервере 80.93.60.208',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
