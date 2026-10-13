import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/user_model.dart';
import '../models/meal_models.dart';
import '../providers/budget_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/meals_provider.dart';
import '../providers/cleaning_provider.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = isMobileLayout(context);
    final asyncs = [
      ref.watch(budgetStateProvider),
      ref.watch(inventoryProvider),
      ref.watch(mealPlanProvider),
      ref.watch(recipesProvider),
      ref.watch(cleaningProvider),
      ref.watch(usersProvider),
    ];
    for (final a in asyncs) {
      if (a.hasError) return ErrorView(a.error!);
    }
    if (asyncs.any((a) => !a.hasValue)) return const LoadingView();

    // Обзор всегда показывает текущий месяц, даже если на вкладке бюджета выбран другой
    final selectedMonth = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year && selectedMonth.month == now.month;

    final budget = ref.watch(budgetStateProvider).value!;
    final inventory = ref.watch(inventoryProvider).value!;
    final mealPlan = ref.watch(mealPlanProvider).value!;
    final recipes = ref.watch(recipesProvider).value!;
    final chores = ref.watch(cleaningProvider).value!;
    final users = ref.watch(usersProvider).value!;
    final me = ref.watch(currentUserProvider);

    final totalLimit = budget.categories.fold(0.0, (s, c) => s + c.limit);
    final totalSpent = budget.expenses.fold(0.0, (s, e) => s + e.amount);
    final remaining = totalLimit - totalSpent;
    final budgetColor = AppTheme.budgetColor(totalSpent, totalLimit);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;

    final runningLow = inventory.where((i) => i.isRunningLow).toList();

    final todayId = planIdFor(now);
    MealPlan? todaysPlan;
    for (final p in mealPlan) {
      if (p.id == todayId) todaysPlan = p;
    }
    Recipe? tonight;
    if (todaysPlan?.recipeId != null) {
      for (final r in recipes) {
        if (r.id == todaysPlan!.recipeId) tonight = r;
      }
    }
    final planned = mealPlan.where((p) => p.recipeId != null).length;

    final doneChores = chores.where((c) => c.isDone).length;
    final choreProgress = chores.isEmpty ? 0.0 : doneChores / chores.length;

    AppUser userFor(String name) => users.firstWhere((u) => u.name == name,
        orElse: () => AppUser(id: '', name: name, pinCode: '', color: AppTheme.textLight));

    final budgetCard = HearthCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Left to spend this month',
              trailing: _LinkButton(label: 'Budget', onTap: () => context.go('/budget'))),
          const SizedBox(height: 14),
          if (!isCurrentMonth)
            const Text('Switch the Budget tab back to this month to see live totals.', style: TextStyle(color: AppTheme.textLight))
          else ...[
            Text(formatMoney(remaining), style: AppTheme.mono(size: mobile ? 40 : 48, color: remaining < 0 ? AppTheme.red : AppTheme.textDark, weight: FontWeight.w500)),
            const SizedBox(height: 18),
            ProgressLine(value: totalLimit > 0 ? totalSpent / totalLimit : 0, color: budgetColor),
            const SizedBox(height: 10),
            Text(
              '${formatMoney(totalSpent)} of ${formatMoney(totalLimit)} spent  ·  $daysLeft days left'
              '${remaining > 0 ? '  ·  ~${formatMoney(remaining / daysLeft)}/day' : ''}',
              style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            ),
          ],
        ],
      ),
    );

    final dinnerCard = HearthCard(
      padding: const EdgeInsets.all(28),
      color: tonight != null ? AppTheme.mossGreen : null,
      borderColor: tonight != null ? AppTheme.mossGreen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TONIGHT'S DINNER", style: AppTheme.eyebrow.copyWith(color: tonight != null ? Colors.white70 : null)),
          const SizedBox(height: 14),
          Text(
            tonight?.name ?? 'Nothing planned yet',
            style: AppTheme.serif(
              size: mobile ? 26 : 30,
              color: tonight != null ? Colors.white : AppTheme.textLight,
              style: tonight == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  tonight != null
                      ? '${tonight.prepTime ?? 30} min  ·  ${todaysPlan!.isCooked ? 'cooked' : 'not cooked yet'}'
                      : '$planned of $plannerDays dinners planned',
                  style: TextStyle(color: tonight != null ? Colors.white70 : AppTheme.textLight, fontSize: 13),
                ),
              ),
              _LinkButton(label: 'Meals', onTap: () => context.go('/meals'), light: tonight != null),
            ],
          ),
        ],
      ),
    );

    final lowCard = HearthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Running low',
              trailing: Text('${runningLow.length} ${runningLow.length == 1 ? 'item' : 'items'}', style: AppTheme.mono(size: 12, color: AppTheme.textLight))),
          const SizedBox(height: 16),
          if (runningLow.isEmpty)
            const EmptyState(icon: Icons.check_circle_outline, message: 'Everything is stocked up.')
          else
            ...runningLow.take(6).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: item.quantity == 0 ? AppTheme.red : AppTheme.amber, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                      Text('${item.quantity} ${item.unit}', style: AppTheme.mono(size: 13, color: AppTheme.textLight)),
                    ],
                  ),
                )),
          if (runningLow.length > 6) ...[
            const SizedBox(height: 8),
            _LinkButton(label: '+${runningLow.length - 6} more in shopping list', onTap: () => context.go('/inventory')),
          ],
        ],
      ),
    );

    final choresCard = HearthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel("This week's chores", trailing: Text('$doneChores/${chores.length}', style: AppTheme.mono(size: 12, color: AppTheme.textLight))),
          const SizedBox(height: 14),
          ProgressLine(value: choreProgress),
          const SizedBox(height: 8),
          if (chores.isEmpty)
            const EmptyState(icon: Icons.cleaning_services_outlined, message: 'No chores yet. Add some on the Cleaning tab.')
          else
            ...chores.take(7).map((chore) {
              final user = userFor(chore.assignee);
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => runSafely(context, () => ref.read(cleaningControllerProvider).toggleStatus(chore.id, chore.isDone)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(value: chore.isDone, onChanged: (_) => ref.read(cleaningControllerProvider).toggleStatus(chore.id, chore.isDone)),
                      Expanded(
                        child: Text(chore.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              decoration: chore.isDone ? TextDecoration.lineThrough : null,
                              color: chore.isDone ? AppTheme.textLight : AppTheme.textDark,
                            )),
                      ),
                      UserTag(name: chore.assignee, color: user.color),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );

    Widget pair(Widget a, Widget b) => mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b])
        : IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 20), Expanded(child: b)]),
          );

    final names = users.isEmpty ? 'No residents' : users.map((u) => u.name).join(' & ');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            subtitle: '$names  ·  ${DateFormat('EEEE, MMMM d').format(now)}',
            title: '${_greeting()}, ${me?.name ?? 'friend'}.',
          ),
          pair(budgetCard, dinnerCard),
          const SizedBox(height: 20),
          mobile
              ? pair(lowCard, choresCard)
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: lowCard), const SizedBox(width: 20), Expanded(child: choresCard)]),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool light;
  const _LinkButton({required this.label, required this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppTheme.mossGreen;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_forward, size: 14, color: color),
        ]),
      ),
    );
  }
}
