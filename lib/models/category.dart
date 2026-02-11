import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String color; // Hex color string

  @HiveField(3)
  bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.color,
    this.isDefault = false,
  });

  // Предустановленные категории
  static List<Category> getDefaultCategories() {
    return [
      Category(id: 1, name: 'Продукты', color: '#4CAF50', isDefault: true),
      Category(id: 2, name: 'Рестораны и кафе', color: '#FF9800', isDefault: true),
      Category(id: 3, name: 'Транспорт', color: '#2196F3', isDefault: true),
      Category(id: 4, name: 'Такси', color: '#FFC107', isDefault: true),
      Category(id: 5, name: 'Топливо (АЗС)', color: '#9C27B0', isDefault: true),
      Category(id: 6, name: 'Коммунальные услуги', color: '#795548', isDefault: true),
      Category(id: 7, name: 'Интернет и связь', color: '#00BCD4', isDefault: true),
      Category(id: 8, name: 'Подписки', color: '#E91E63', isDefault: true),
      Category(id: 9, name: 'Одежда и обувь', color: '#673AB7', isDefault: true),
      Category(id: 10, name: 'Красота и здоровье', color: '#F06292', isDefault: true),
      Category(id: 11, name: 'Аптека', color: '#EF5350', isDefault: true),
      Category(id: 12, name: 'Спорт и фитнес', color: '#66BB6A', isDefault: true),
      Category(id: 13, name: 'Развлечения', color: '#AB47BC', isDefault: true),
      Category(id: 14, name: 'Путешествия', color: '#42A5F5', isDefault: true),
      Category(id: 15, name: 'Образование', color: '#5C6BC0', isDefault: true),
      Category(id: 16, name: 'Дом и ремонт', color: '#8D6E63', isDefault: true),
      Category(id: 17, name: 'Электроника', color: '#78909C', isDefault: true),
      Category(id: 18, name: 'Подарки', color: '#EC407A', isDefault: true),
      Category(id: 19, name: 'Благотворительность', color: '#26C6DA', isDefault: true),
      Category(id: 20, name: 'Прочее', color: '#9E9E9E', isDefault: true),
    ];
  }
}
