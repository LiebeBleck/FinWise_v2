import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/savings_goal.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

class SavingsGoalsScreen extends StatelessWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      body: ResponsiveHelper.constrain(
        Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable:
                    HiveService.savingsGoalsBox.listenable(),
                builder: (context, Box<SavingsGoal> box, _) {
                  final goals = box.values.toList();
                  return goals.isEmpty
                      ? _buildEmpty(context, isDark)
                      : _buildGoalsList(context, goals, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: AppTheme.primaryColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Цели сбережений',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: () => _showGoalSheet(context, null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет целей сбережений',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте цель и следите\nза прогрессом накоплений',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showGoalSheet(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Добавить цель'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Goals list ─────────────────────────────────────────

  Widget _buildGoalsList(
      BuildContext context, List<SavingsGoal> goals, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (context, index) =>
          _buildGoalCard(context, goals[index], isDark),
    );
  }

  Widget _buildGoalCard(
      BuildContext context, SavingsGoal goal, bool isDark) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final color = _parseColor(goal.color ?? '#F97316');
    final monthly = goal.monthlySavingsNeeded;
    final remaining = goal.targetAmount - goal.savedAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    goal.icon ?? '🎯',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (goal.deadline != null)
                      Text(
                        'До ${DateFormat('d MMM yyyy', 'ru_RU').format(goal.deadline!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showGoalSheet(context, goal);
                  } else if (value == 'delete') {
                    await _confirmDelete(context, goal);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Редактировать'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor:
                  isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                  goal.isCompleted ? const Color(0xFF22C55E) : color),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                '${fmt.format(goal.savedAmount)} ₽',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Text(' из '),
              Text(
                '${fmt.format(goal.targetAmount)} ₽',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const Spacer(),
              Text(
                '${(goal.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: goal.isCompleted
                      ? const Color(0xFF22C55E)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),

          if (goal.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
                  const SizedBox(width: 4),
                  const Text('Цель достигнута! 🎉',
                      style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (monthly != null && monthly > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Откладывайте ${fmt.format(monthly)} ₽/мес для достижения цели',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic),
              ),
            ),

          const SizedBox(height: 12),

          // Buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showTopUpDialog(context, goal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Пополнить'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  remaining > 0
                      ? 'Осталось: ${fmt.format(remaining)} ₽'
                      : 'Накоплено!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top-up dialog ──────────────────────────────────────

  void _showTopUpDialog(BuildContext context, SavingsGoal goal) {
    final ctrl = TextEditingController();
    final fmt = NumberFormat('#,##0', 'ru_RU');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пополнить цель'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Накоплено: ${fmt.format(goal.savedAmount)} / ${fmt.format(goal.targetAmount)} ₽',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сумма пополнения',
                suffixText: '₽',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              goal.savedAmount =
                  (goal.savedAmount + amount).clamp(0, goal.targetAmount);
              await goal.save();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
  }

  // ── Goal add/edit sheet ────────────────────────────────

  static const _colorOptions = [
    '#F97316', '#EF4444', '#22C55E', '#3B82F6', '#8B5CF6',
    '#EC4899', '#F59E0B', '#14B8A6', '#6366F1', '#84CC16',
  ];

  static const _iconOptions = [
    '🎯', '✈️', '🏠', '🚗', '💻', '📱', '🎓', '💍', '🏖️', '🏋️',
    '🎮', '📚', '🎸', '🌍', '💰', '🏦', '🎁', '🐾', '🌱', '⭐',
  ];

  void _showGoalSheet(BuildContext context, SavingsGoal? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(
      text: existing?.targetAmount.toStringAsFixed(0) ?? '',
    );
    String selectedColor = existing?.color ?? _colorOptions[0];
    String selectedIcon = existing?.icon ?? _iconOptions[0];
    DateTime? deadline = existing?.deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) => SingleChildScrollView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing != null ? 'Редактировать цель' : 'Новая цель',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Название цели',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Target amount
                    TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Целевая сумма',
                        suffixText: '₽',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Deadline
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: deadline ??
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setModalState(() => deadline = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Дедлайн (необязательно)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          suffixIcon: deadline != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setModalState(() => deadline = null),
                                )
                              : const Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          deadline != null
                              ? DateFormat('d MMMM yyyy', 'ru_RU')
                                  .format(deadline!)
                              : 'Выбрать дату',
                          style: TextStyle(
                              color: deadline != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Icon picker
                    Text('Иконка',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((icon) {
                        final selected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedIcon = icon),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryColor
                                      .withValues(alpha: 0.15)
                                  : (isDark
                                      ? const Color(0xFF3C3C3C)
                                      : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                              border: selected
                                  ? Border.all(
                                      color: AppTheme.primaryColor, width: 2)
                                  : null,
                            ),
                            child: Center(
                                child: Text(icon,
                                    style:
                                        const TextStyle(fontSize: 22))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text('Цвет',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((hex) {
                        final color = _parseColor(hex);
                        final selected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 6)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final target = double.tryParse(targetCtrl.text);
                          if (name.isEmpty || target == null || target <= 0) {
                            return;
                          }
                          if (existing != null) {
                            existing.name = name;
                            existing.targetAmount = target;
                            existing.deadline = deadline;
                            existing.icon = selectedIcon;
                            existing.color = selectedColor;
                            await existing.save();
                          } else {
                            final goal = SavingsGoal(
                              id: const Uuid().v4(),
                              name: name,
                              targetAmount: target,
                              createdAt: DateTime.now(),
                              deadline: deadline,
                              icon: selectedIcon,
                              color: selectedColor,
                            );
                            await HiveService.savingsGoalsBox
                                .put(goal.id, goal);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                            existing != null ? 'Сохранить' : 'Создать цель'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, SavingsGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить цель?'),
        content: Text('Удалить "${goal.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) await goal.delete();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }
}
