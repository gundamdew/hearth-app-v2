import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String assignee;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.assignee,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'assignee': assignee,
    };
  }

  factory Expense.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Expense(
      id: documentId,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignee: map['assignee'] ?? '',
    );
  }
}

class Income {
  final String id;
  final String title;
  final double amount;
  final String assignee;
  final DateTime date;

  Income({
    required this.id,
    required this.title,
    required this.amount,
    required this.assignee,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'assignee': assignee,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Income.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Income(
      id: documentId,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      assignee: map['assignee'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class BudgetCategory {
  final String id;
  final String name;
  final double limit;
  final double currentSpent;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.limit,
    this.currentSpent = 0.0,
  });

  BudgetCategory copyWith({String? id, String? name, double? limit, double? currentSpent}) {
    return BudgetCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      limit: limit ?? this.limit,
      currentSpent: currentSpent ?? this.currentSpent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'limit': limit,
    };
  }

  factory BudgetCategory.fromFirestore(Map<String, dynamic> map, String documentId) {
    return BudgetCategory(
      id: documentId,
      name: map['name'] ?? '',
      limit: (map['limit'] ?? 0).toDouble(),
      // currentSpent вычисляется динамически на основе расходов, поэтому в БД не сохраняем
      currentSpent: 0.0,
    );
  }
}

class BudgetState {
  final List<BudgetCategory> categories;
  final List<Expense> expenses;
  final List<Income> incomes;

  BudgetState({
    required this.categories,
    required this.expenses,
    required this.incomes,
  });

  BudgetState copyWith({
    List<BudgetCategory>? categories,
    List<Expense>? expenses,
    List<Income>? incomes,
  }) {
    return BudgetState(
      categories: categories ?? this.categories,
      expenses: expenses ?? this.expenses,
      incomes: incomes ?? this.incomes,
    );
  }
}