import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoriesBox = Hive.box<Category>('categories');
    final category = categoriesBox.get(transaction.categoryId);

    final dateFormat = DateFormat('d MMM, HH:mm', 'ru_RU');
    final numberFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor(category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(category?.name),
            color: _getCategoryColor(category),
            size: 24,
          ),
        ),
        title: Text(
          transaction.description.isNotEmpty
              ? transaction.description
              : category?.name ?? 'Без категории',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                category?.name ?? 'Без категории',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(transaction.date),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Text(
          '${transaction.isIncome ? '+' : '-'}${numberFormat.format(transaction.absoluteAmount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.isIncome ? Colors.green[600] : Colors.red[600],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(Category? category) {
    if (category == null) return Colors.grey;
    try {
      return Color(int.parse(category.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.category;

    switch (categoryName) {
      case 'Продукты':
        return Icons.shopping_cart;
      case 'Рестораны и кафе':
        return Icons.restaurant;
      case 'Транспорт':
        return Icons.directions_bus;
      case 'Такси':
        return Icons.local_taxi;
      case 'Топливо (АЗС)':
        return Icons.local_gas_station;
      case 'Коммунальные услуги':
        return Icons.home;
      case 'Интернет и связь':
        return Icons.wifi;
      case 'Подписки':
        return Icons.subscriptions;
      case 'Одежда и обувь':
        return Icons.checkroom;
      case 'Красота и здоровье':
        return Icons.spa;
      case 'Аптека':
        return Icons.local_pharmacy;
      case 'Спорт и фитнес':
        return Icons.fitness_center;
      case 'Развлечения':
        return Icons.theater_comedy;
      case 'Путешествия':
        return Icons.flight;
      case 'Образование':
        return Icons.school;
      case 'Дом и ремонт':
        return Icons.construction;
      case 'Электроника':
        return Icons.devices;
      case 'Подарки':
        return Icons.card_giftcard;
      case 'Благотворительность':
        return Icons.volunteer_activism;
      default:
        return Icons.category;
    }
  }
}
