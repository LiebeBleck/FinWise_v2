import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable:
                  Hive.box<Transaction>('transactions').listenable(),
              builder: (context, Box<Transaction> transactionsBox, _) {
                final allTransactions = transactionsBox.values.toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                if (allTransactions.isEmpty) {
                  return _buildEmptyState();
                }

                final grouped = _groupTransactions(allTransactions);

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped[index];
                    if (entry is String) {
                      return _buildGroupHeader(entry);
                    } else if (entry is Transaction) {
                      return _buildNotificationItem(context, entry);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFFFB923C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 8,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Уведомления',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: 56,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Нет уведомлений',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь будут отображаться\nваши транзакции',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _groupTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));

    final List<dynamic> result = [];
    String? lastGroup;

    for (final t in transactions) {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);

      String group;
      if (tDate.isAtSameMomentAs(today)) {
        group = 'Сегодня';
      } else if (tDate.isAtSameMomentAs(yesterday)) {
        group = 'Вчера';
      } else if (tDate.isAfter(thisWeekStart)) {
        group = 'На этой неделе';
      } else if (tDate.isAfter(DateTime(now.year, now.month, 1))) {
        group = 'В этом месяце';
      } else {
        group = 'Ранее';
      }

      if (group != lastGroup) {
        result.add(group);
        lastGroup = group;
      }
      result.add(t);
    }

    return result;
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, Transaction transaction) {
    final categoriesBox = Hive.box<Category>('categories');
    final category = categoriesBox.get(transaction.categoryId);
    final categoryName = category?.name ?? 'Без категории';

    Color categoryColor;
    try {
      categoryColor = Color(
        int.parse(category?.color.replaceFirst('#', '0xFF') ?? '0xFFF97316'),
      );
    } catch (e) {
      categoryColor = AppTheme.primaryColor;
    }

    final timeFormat = DateFormat('HH:mm', 'ru_RU');
    final dateFormat = DateFormat('d MMM', 'ru_RU');
    final numberFormat =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    final String notifTitle;
    final String notifBody;
    final IconData notifIcon;

    if (transaction.isPlanned) {
      notifTitle = 'Планируемая трата';
      notifBody = transaction.description.isNotEmpty
          ? transaction.description
          : categoryName;
      notifIcon = Icons.event_available_outlined;
    } else if (transaction.isIncome) {
      notifTitle = 'Доход получен';
      notifBody = transaction.description.isNotEmpty
          ? transaction.description
          : categoryName;
      notifIcon = Icons.trending_up;
    } else {
      notifTitle = 'Транзакция';
      notifBody = transaction.description.isNotEmpty
          ? transaction.description
          : categoryName;
      notifIcon = Icons.receipt_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notifIcon,
                color: categoryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notifTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        '${transaction.isIncome ? '+' : '-'}${numberFormat.format(transaction.absoluteAmount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: transaction.isIncome
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notifBody,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          color: categoryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '  •  ',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        '${timeFormat.format(transaction.date)} — ${dateFormat.format(transaction.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
