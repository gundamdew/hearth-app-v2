import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/models/budget_models.dart';
import 'package:hearth/models/inventory_item.dart';
import 'package:hearth/models/user_model.dart';
import 'package:hearth/providers/budget_provider.dart';
import 'package:hearth/theme.dart';

Expense _exp(String who, double amount) =>
    Expense(id: '', title: 'x', amount: amount, category: 'Groceries', date: DateTime(2025, 1, 1), assignee: who);

void main() {
  final maya = AppUser(id: '1', name: 'Maya', pinCode: '1111', color: AppTheme.terracotta);
  final jonah = AppUser(id: '2', name: 'Jonah', pinCode: '2222', color: AppTheme.sage);

  group('calculateDebt', () {
    test('reports who owes the difference to the fair share', () {
      expect(calculateDebt([_exp('Maya', 100), _exp('Jonah', 40)], [maya, jonah]), 'Jonah owes \$30');
    });
    test('balanced when both paid the same', () {
      expect(calculateDebt([_exp('Maya', 50), _exp('Jonah', 50)], [maya, jonah]), 'Contributions are perfectly balanced.');
    });
    test('handles no expenses', () {
      expect(calculateDebt([], [maya, jonah]), 'No shared expenses this month.');
    });
  });

  group('budgetColor', () {
    test('green, amber, red thresholds', () {
      expect(AppTheme.budgetColor(50, 100), AppTheme.mossGreen);
      expect(AppTheme.budgetColor(85, 100), AppTheme.amber);
      expect(AppTheme.budgetColor(120, 100), AppTheme.red);
    });
  });

  test('InventoryItem.isRunningLow at or below threshold', () {
    final item = InventoryItem(id: '', name: 'Milk', location: 'Fridge', quantity: 1, unit: 'l', lowStockThreshold: 1);
    expect(item.isRunningLow, isTrue);
    expect(item.copyWith(quantity: 3).isRunningLow, isFalse);
  });

  test('AppUser colour survives a Firestore round trip', () {
    final restored = AppUser.fromFirestore(maya.toMap(), maya.id);
    expect(restored.color.toARGB32(), maya.color.toARGB32());
    expect(restored.name, 'Maya');
  });
}
