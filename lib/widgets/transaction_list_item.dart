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

    final dateFormat = DateFormat('d MMM', 'ru_RU');
    final numberFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    final categoryColor = _getCategoryColor(category);

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Circular icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(category?.name),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description.isNotEmpty
                          ? transaction.description
                          : category?.name ?? 'Без категории',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          dateFormat.format(transaction.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          '  •  ',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Flexible(
                          child: Text(
                            category?.name ?? 'Без категории',
                            style: TextStyle(
                              fontSize: 12,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Amount
              Text(
                '${transaction.isIncome ? '+' : '-'}${numberFormat.format(transaction.absoluteAmount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: transaction.isIncome
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
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
