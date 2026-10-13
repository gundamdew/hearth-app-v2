import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/meal_models.dart';

/// Сколько дней вперёд показывает планировщик.
const plannerDays = 14;

final _recipes = FirebaseFirestore.instance.collection('recipes');
final _plans = FirebaseFirestore.instance.collection('meal_plans');
final _inventory = FirebaseFirestore.instance.collection('inventory');

String planIdFor(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

final recipesProvider = StreamProvider<List<Recipe>>((ref) {
  return _recipes.snapshots().map((snapshot) {
    final list = snapshot.docs.map((doc) => Recipe.fromFirestore(doc.data(), doc.id)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });
});

final mealPlanProvider = StreamProvider<List<MealPlan>>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return _plans
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .orderBy('date')
      .limit(plannerDays)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MealPlan.fromFirestore(doc.data(), doc.id)).toList());
});

final mealsControllerProvider = Provider((ref) => MealsController(ref));

class MealsController {
  final Ref _ref;
  final _db = FirebaseFirestore.instance;

  MealsController(this._ref);

  /// Создаёт пустые дни плана на две недели вперёд одним запросом вместо 14 отдельных чтений.
  Future<void> initializeMealPlans() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existing = await _plans.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today)).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    final batch = _db.batch();
    var added = 0;
    for (var i = 0; i < plannerDays; i++) {
      final date = today.add(Duration(days: i));
      final id = planIdFor(date);
      if (existingIds.contains(id)) continue;
      batch.set(_plans.doc(id), {'date': Timestamp.fromDate(date), 'recipeId': null, 'isCooked': false});
      added++;
    }
    if (added > 0) await batch.commit();
  }

  Future<void> addRecipe(String name, int prepTime, List<RecipeIngredient> ingredients) {
    return _recipes.add(Recipe(id: '', name: name, prepTime: prepTime, ingredients: ingredients).toMap());
  }

  /// Удаляет рецепт и снимает его со всех будущих дней плана.
  Future<void> deleteRecipe(String recipeId) async {
    final batch = _db.batch();
    final plans = _ref.read(mealPlanProvider).value ?? [];
    for (final plan in plans.where((p) => p.recipeId == recipeId && !p.isCooked)) {
      batch.update(_plans.doc(plan.id), {'recipeId': null, 'isCooked': false});
    }
    batch.delete(_recipes.doc(recipeId));
    await batch.commit();
  }

  Future<void> assignRecipe(String mealPlanId, String recipeId) {
    return _plans.doc(mealPlanId).update({'recipeId': recipeId, 'isCooked': false});
  }

  Future<void> clearRecipe(String mealPlanId) {
    return _plans.doc(mealPlanId).update({'recipeId': null, 'isCooked': false});
  }

  Recipe? _recipe(String id) {
    final recipes = _ref.read(recipesProvider).value ?? [];
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Киллер-фича: списывает ингредиенты рецепта со склада.
  /// Транзакция гарантирует, что количество не уйдёт в минус и не будет гонок между двумя устройствами.
  Future<void> markCooked(String mealPlanId, String recipeId) async {
    final recipe = _recipe(recipeId);
    if (recipe == null) throw StateError('Recipe not found');

    await _db.runTransaction((tx) async {
      final planRef = _plans.doc(mealPlanId);
      final planSnap = await tx.get(planRef);
      if (planSnap.data()?['isCooked'] == true) return;

      final ingredients = recipe.ingredients.where((i) => i.inventoryId.isNotEmpty).toList();
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ing in ingredients) {
        snaps.add(await tx.get(_inventory.doc(ing.inventoryId)));
      }
      for (var i = 0; i < ingredients.length; i++) {
        if (!snaps[i].exists) continue;
        final current = (snaps[i].data()?['quantity'] as num?)?.toInt() ?? 0;
        final next = (current - ingredients[i].quantity).clamp(0, 999);
        tx.update(snaps[i].reference, {'quantity': next});
      }
      tx.update(planRef, {'isCooked': true});
    });
  }

  /// Отменяет «приготовлено» и возвращает ингредиенты на склад.
  Future<void> undoCooked(String mealPlanId, String recipeId) async {
    final recipe = _recipe(recipeId);
    final batch = _db.batch();
    if (recipe != null) {
      for (final ing in recipe.ingredients.where((i) => i.inventoryId.isNotEmpty)) {
        batch.update(_inventory.doc(ing.inventoryId), {'quantity': FieldValue.increment(ing.quantity)});
      }
    }
    batch.update(_plans.doc(mealPlanId), {'isCooked': false});
    await batch.commit();
  }
}
