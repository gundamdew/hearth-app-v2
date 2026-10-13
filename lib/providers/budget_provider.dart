import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_models.dart';
import '../models/user_model.dart';

final _transactions = FirebaseFirestore.instance.collection('budget_transactions');
final _categories = FirebaseFirestore.instance.collection('budget_categories');

/// Выбранный месяц (первое число месяца). По умолчанию — текущий.
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);
  void next() => state = DateTime(state.year, state.month + 1);
  void reset() => state = build();
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(SelectedMonthNotifier.new);

final _allTransactionsProvider = StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return _transactions.snapshots().map((s) => s.docs);
});

final categoriesProvider = StreamProvider<List<BudgetCategory>>((ref) {
  return _categories.snapshots().map((snapshot) {
    final list = snapshot.docs.map((doc) => BudgetCategory.fromFirestore(doc.data(), doc.id)).toList();
    list.sort((a, b) => b.limit.compareTo(a.limit));
    return list;
  });
});

bool _inMonth(DateTime date, DateTime month) => date.year == month.year && date.month == month.month;

/// Состояние бюджета за выбранный месяц.
final budgetStateProvider = Provider<AsyncValue<BudgetState>>((ref) {
  final txAsync = ref.watch(_allTransactionsProvider);
  final catsAsync = ref.watch(categoriesProvider);
  final month = ref.watch(selectedMonthProvider);

  if (txAsync.hasError) return AsyncError(txAsync.error!, txAsync.stackTrace ?? StackTrace.current);
  if (catsAsync.hasError) return AsyncError(catsAsync.error!, catsAsync.stackTrace ?? StackTrace.current);
  if (!txAsync.hasValue || !catsAsync.hasValue) return const AsyncLoading();

  final docs = txAsync.value!;
  final expenses = docs
      .where((d) => d.data()['type'] == 'expense')
      .map((d) => Expense.fromFirestore(d.data(), d.id))
      .where((e) => _inMonth(e.date, month))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final incomes = docs
      .where((d) => d.data()['type'] == 'income')
      .map((d) => Income.fromFirestore(d.data(), d.id))
      .where((i) => _inMonth(i.date, month))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final categories = catsAsync.value!.map((cat) {
    final spent = expenses.where((e) => e.category == cat.name).fold(0.0, (t, e) => t + e.amount);
    return cat.copyWith(currentSpent: spent);
  }).toList();

  return AsyncData(BudgetState(categories: categories, expenses: expenses, incomes: incomes));
});

final budgetControllerProvider = Provider((ref) => BudgetController());

class BudgetController {
  final _db = FirebaseFirestore.instance;

  Future<void> initializeCategories() async {
    final snap = await _categories.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _db.batch();
    const defaults = {
      'Groceries': 800.0, 'Rent': 1650.0, 'Utilities': 200.0,
      'Household': 100.0, 'Transport': 150.0, 'Eating out': 300.0,
    };
    defaults.forEach((name, limit) => batch.set(_categories.doc(), {'name': name, 'limit': limit}));
    await batch.commit();
  }

  Future<void> addExpense(String title, double amount, String categoryName, String assignee) {
    return _transactions.add({
      'type': 'expense',
      'title': title,
      'amount': amount,
      'category': categoryName,
      // Клиентское время, чтобы транзакция сразу попадала в нужный месяц
      'date': Timestamp.now(),
      'assignee': assignee,
    });
  }

  Future<void> addIncome(String title, double amount, String assignee) {
    return _transactions.add({
      'type': 'income',
      'title': title,
      'amount': amount,
      'assignee': assignee,
      'date': Timestamp.now(),
    });
  }

  Future<void> deleteTransaction(String id) => _transactions.doc(id).delete();

  Future<void> addCategory(String name, double limit) => _categories.add({'name': name, 'limit': limit});

  Future<void> updateCategoryLimit(String id, double newLimit) => _categories.doc(id).update({'limit': newLimit});

  Future<void> deleteCategory(String id) => _categories.doc(id).delete();
}

/// Строка взаиморасчётов: кто сколько должен, чтобы расходы поделились поровну.
String calculateDebt(List<Expense> expenses, List<AppUser> users) {
  if (users.isEmpty) return 'No residents added yet.';
  if (users.length == 1) return 'Only one resident — nothing to settle.';
  if (expenses.isEmpty) return 'No shared expenses this month.';

  final total = expenses.fold(0.0, (t, e) => t + e.amount);
  final fairShare = total / users.length;

  final debtors = <String>[];
  for (final user in users) {
    final spent = expenses.where((e) => e.assignee == user.name).fold(0.0, (t, e) => t + e.amount);
    if (spent < fairShare - 0.5) {
      debtors.add('${user.name} owes \$${(fairShare - spent).toStringAsFixed(0)}');
    }
  }
  return debtors.isEmpty ? 'Contributions are perfectly balanced.' : debtors.join('  ·  ');
}
