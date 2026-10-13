import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeIngredient {
  final String inventoryId;
  final String name;
  final int quantity;

  RecipeIngredient({
    required this.inventoryId,
    required this.name,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId,
      'name': name,
      'quantity': quantity,
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      inventoryId: map['inventoryId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity']?.toInt() ?? 1,
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final int? prepTime;

  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.prepTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'prepTime': prepTime,
      'ingredients': ingredients.map((x) => x.toMap()).toList(),
    };
  }

  factory Recipe.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Recipe(
      id: documentId,
      name: map['name'] ?? '',
      prepTime: map['prepTime']?.toInt(),
      ingredients: List<RecipeIngredient>.from(
        (map['ingredients'] as List<dynamic>? ?? []).map((x) => RecipeIngredient.fromMap(x)),
      ),
    );
  }
}

class MealPlan {
  final String id;
  final DateTime date;
  final String? recipeId;
  final bool isCooked;

  MealPlan({
    required this.id,
    required this.date,
    this.recipeId,
    this.isCooked = false,
  });

  MealPlan copyWith({String? id, DateTime? date, String? recipeId, bool? isCooked}) {
    return MealPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      recipeId: recipeId ?? this.recipeId,
      isCooked: isCooked ?? this.isCooked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'recipeId': recipeId,
      'isCooked': isCooked,
    };
  }

  factory MealPlan.fromFirestore(Map<String, dynamic> map, String documentId) {
    return MealPlan(
      id: documentId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipeId: map['recipeId'],
      isCooked: map['isCooked'] ?? false,
    );
  }
}