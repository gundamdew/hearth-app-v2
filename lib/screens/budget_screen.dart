import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/budget_models.dart';
import '../models/user_model.dart';
import '../providers/budget_provider.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  String? _selectedAssignee;
  String _type = 'Expense';

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final controller = ref.read(budgetControllerProvider);

    String? problem;
    if (amount <= 0) problem = 'Enter an amount greater than zero';
    if (_selectedAssignee == null) problem = 'Choose who paid';
    if (_type == 'Expense' && _selectedCategory == null) problem = 'Choose a category';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    final label = title.isEmpty ? (_selectedCategory ?? 'Income') : title;
    final ok = await runSafely(
      context,
      () => _type == 'Expense'
          ? controller.addExpense(label, amount, _selectedCategory!, _selectedAssignee!)
          : controller.addIncome(label, amount, _selectedAssignee!),
      success: '${_type == 'Expense' ? 'Expense' : 'Income'} of ${formatMoney(amount)} logged',
    );
    if (ok && mounted) {
      _titleController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _editCategory(BudgetCategory? cat) async {
    final nameCtrl = TextEditingController(text: cat?.name ?? '');
    final limitCtrl = TextEditingController(text: cat != null ? cat.limit.toStringAsFixed(0) : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cat == null ? 'New category' : cat.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (cat == null) ...[
            TextField(controller: nameCtrl, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: limitCtrl,
            autofocus: cat != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '\$ '),
          ),
        ]),
        actions: [
          if (cat != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.red),
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final controller = ref.read(budgetControllerProvider);
    if (result == 'delete' && cat != null) {
      if (await confirmDelete(context, 'category "${cat.name}"') && mounted) {
        await runSafely(context, () => controller.deleteCategory(cat.id));
      }
      return;
    }
    final limit = double.tryParse(limitCtrl.text.replaceAll(',', '.'));
    if (limit == null || limit < 0) return;
    if (cat == null) {
      final name = nameCtrl.text.trim();
      if (name.isNotEmpty) await runSafely(context, () => controller.addCategory(name, limit));
    } else {
      await runSafely(context, () => controller.updateCategoryLimit(cat.id, limit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobileLayout(context);
    final budgetAsync = ref.watch(budgetStateProvider);
    final usersAsync = ref.watch(usersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final month = ref.watch(selectedMonthProvider);

    if (budgetAsync.hasError) return ErrorView(budgetAsync.error!);
    if (usersAsync.hasError) return ErrorView(usersAsync.error!);
    if (!budgetAsync.hasValue || !usersAsync.hasValue) return const LoadingView();

    final budget = budgetAsync.value!;
    final users = usersAsync.value!;
    final names = users.map((u) => u.name).toList();

    if (_selectedAssignee == null || !names.contains(_selectedAssignee)) {
      _selectedAssignee = currentUser != null && names.contains(currentUser.name)
          ? currentUser.name
          : (names.isNotEmpty ? names.first : null);
    }
    if (_selectedCategory != null && !budget.categories.any((c) => c.name == _selectedCategory)) {
      _selectedCategory = null;
    }

    final totalLimit = budget.categories.fold(0.0, (s, c) => s + c.limit);
    final totalSpent = budget.expenses.fold(0.0, (s, e) => s + e.amount);
    final totalIncome = budget.incomes.fold(0.0, (s, i) => s + i.amount);
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;

    final monthSwitcher = Container(
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.hairline)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () => ref.read(selectedMonthProvider.notifier).previous(),
        ),
        InkWell(
          onTap: isCurrent ? null : () => ref.read(selectedMonthProvider.notifier).reset(),
          child: SizedBox(
            width: 120,
            child: Text(DateFormat('MMMM yyyy').format(month), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: isCurrent ? null : () => ref.read(selectedMonthProvider.notifier).next(),
        ),
      ]),
    );

    final summary = HearthCard(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Remaining of monthly limit'),
        const SizedBox(height: 12),
        Text(formatMoney(totalLimit - totalSpent),
            style: AppTheme.mono(size: mobile ? 38 : 46, weight: FontWeight.w500, color: totalSpent > totalLimit ? AppTheme.red : AppTheme.textDark)),
        const SizedBox(height: 16),
        ProgressLine(value: totalLimit > 0 ? totalSpent / totalLimit : 0, color: AppTheme.budgetColor(totalSpent, totalLimit)),
        const SizedBox(height: 18),
        Wrap(spacing: 28, runSpacing: 12, children: [
          _Stat(label: 'Limit', value: formatMoney(totalLimit)),
          _Stat(label: 'Spent', value: formatMoney(totalSpent)),
          _Stat(label: 'Income', value: formatMoney(totalIncome)),
          _Stat(label: 'Net', value: formatMoney(totalIncome - totalSpent), color: totalIncome - totalSpent < 0 ? AppTheme.red : AppTheme.mossGreen),
        ]),
      ]),
    );

    final settlement = HearthCard(
      color: AppTheme.sage.withValues(alpha: 0.12),
      borderColor: AppTheme.sage.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Settlement balance'),
        const SizedBox(height: 8),
        Text(calculateDebt(budget.expenses, users), style: AppTheme.serif(size: 18)),
        if (users.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: users.map((u) => _ResidentSpend(user: u, budget: budget)).toList(),
          ),
        ],
      ]),
    );

    final categories = HearthCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel('Categories',
            trailing: TextButton.icon(onPressed: () => _editCategory(null), icon: const Icon(Icons.add, size: 16), label: const Text('Add'))),
        const SizedBox(height: 8),
        if (budget.categories.isEmpty) const EmptyState(icon: Icons.category_outlined, message: 'No categories yet.'),
        for (final cat in budget.categories) _CategoryRow(category: cat, onTap: () => _editCategory(cat)),
      ]),
    );

    final form = HearthCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Log a transaction', style: AppTheme.serif(size: 20)),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'Expense', label: Text('Expense')), ButtonSegment(value: 'Income', label: Text('Income'))],
          selected: {_type},
          onSelectionChanged: (v) => setState(() => _type = v.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: AppTheme.mono(size: 22),
          decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
        ),
        const SizedBox(height: 12),
        TextField(controller: _titleController, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Description (optional)')),
        if (_type == 'Expense') ...[
          const SizedBox(height: 16),
          Text('CATEGORY', style: AppTheme.eyebrow),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in budget.categories)
              ChoiceChip(
                label: Text(c.name),
                selected: _selectedCategory == c.name,
                showCheckmark: false,
                selectedColor: AppTheme.mossGreen,
                labelStyle: TextStyle(color: _selectedCategory == c.name ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.w500),
                side: const BorderSide(color: AppTheme.hairline),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _selectedCategory = c.name),
              ),
          ]),
        ],
        const SizedBox(height: 16),
        Text(_type == 'Expense' ? 'PAID BY' : 'RECEIVED BY', style: AppTheme.eyebrow),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final u in users)
            ChoiceChip(
              avatar: UserAvatar(user: u, radius: 10),
              label: Text(u.name),
              selected: _selectedAssignee == u.name,
              showCheckmark: false,
              selectedColor: u.color.withValues(alpha: 0.22),
              side: BorderSide(color: _selectedAssignee == u.name ? u.color : AppTheme.hairline),
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => _selectedAssignee = u.name),
            ),
        ]),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _submit, child: Text('Add ${_type.toLowerCase()}')),
      ]),
    );

    final recent = HearthCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel('Recent transactions', trailing: Text('${budget.expenses.length + budget.incomes.length}', style: AppTheme.mono(size: 12, color: AppTheme.textLight))),
        const SizedBox(height: 8),
        if (budget.expenses.isEmpty && budget.incomes.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, message: 'No transactions this month.'),
        ..._mergedTransactions(budget).take(25).map((t) => _TransactionRow(tx: t, users: users)),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(subtitle: 'Budget', title: 'Where the money goes', actions: [monthSwitcher]),
        if (mobile) ...[
          summary, const SizedBox(height: 16), form, const SizedBox(height: 16),
          settlement, const SizedBox(height: 16), categories, const SizedBox(height: 16), recent,
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                summary, const SizedBox(height: 20), settlement, const SizedBox(height: 20), categories,
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [form, const SizedBox(height: 20), recent]),
            ),
          ]),
      ]),
    );
  }

  List<_Tx> _mergedTransactions(BudgetState b) {
    final list = [
      ...b.expenses.map((e) => _Tx(e.id, e.title, e.category, e.assignee, e.amount, e.date, false)),
      ...b.incomes.map((i) => _Tx(i.id, i.title, 'Income', i.assignee, i.amount, i.date, true)),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

class _Tx {
  final String id, title, category, assignee;
  final double amount;
  final DateTime date;
  final bool isIncome;
  _Tx(this.id, this.title, this.category, this.assignee, this.amount, this.date, this.isIncome);
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, this.color = AppTheme.textDark});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTheme.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.mono(size: 15, color: color)),
      ]);
}

class _ResidentSpend extends StatelessWidget {
  final AppUser user;
  final BudgetState budget;
  const _ResidentSpend({required this.user, required this.budget});

  @override
  Widget build(BuildContext context) {
    final inc = budget.incomes.where((i) => i.assignee == user.name).fold(0.0, (s, i) => s + i.amount);
    final out = budget.expenses.where((e) => e.assignee == user.name).fold(0.0, (s, e) => s + e.amount);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        UserAvatar(user: user, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, style: TextStyle(fontWeight: FontWeight.w700, color: user.color)),
            Text('paid ${formatMoney(out)}', style: AppTheme.mono(size: 12, color: AppTheme.textLight)),
            if (inc > 0) Text('earned ${formatMoney(inc)}', style: AppTheme.mono(size: 12, color: AppTheme.textLight)),
          ]),
        ),
      ]),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final BudgetCategory category;
  final VoidCallback onTap;
  const _CategoryRow({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.budgetColor(category.currentSpent, category.limit);
    final over = category.currentSpent > category.limit;
    final left = category.limit - category.currentSpent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(category.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Text('${formatMoney(category.currentSpent)} / ${formatMoney(category.limit)}', style: AppTheme.mono(size: 13, color: AppTheme.textLight)),
          ]),
          const SizedBox(height: 10),
          ProgressLine(value: category.limit > 0 ? category.currentSpent / category.limit : 0, color: color),
          const SizedBox(height: 6),
          Text(
            over ? '${formatMoney(-left)} over limit' : '${formatMoney(left)} left',
            style: TextStyle(fontSize: 12, color: color == AppTheme.mossGreen ? AppTheme.textLight : color, fontWeight: over ? FontWeight.w600 : FontWeight.w400),
          ),
        ]),
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  final _Tx tx;
  final List<AppUser> users;
  const _TransactionRow({required this.tx, required this.users});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = users.where((u) => u.name == tx.assignee).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        UserAvatar(user: user, radius: 15),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text('${tx.category}  ·  ${DateFormat('MMM d').format(tx.date)}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
          ]),
        ),
        Text('${tx.isIncome ? '+' : '−'}${formatMoney(tx.amount)}',
            style: AppTheme.mono(size: 14, color: tx.isIncome ? AppTheme.mossGreen : AppTheme.textDark)),
        IconButton(
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 16, color: AppTheme.textLight),
          onPressed: () async {
            if (await confirmDelete(context, '"${tx.title}"') && context.mounted) {
              await runSafely(context, () => ref.read(budgetControllerProvider).deleteTransaction(tx.id));
            }
          },
        ),
      ]),
    );
  }
}
