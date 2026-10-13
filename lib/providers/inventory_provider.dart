import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';

/// Места хранения в фиксированном порядке отображения.
const inventoryLocations = ['Pantry', 'Fridge', 'Freezer', 'Household', 'Laundry'];

final inventoryProvider = StreamProvider<List<InventoryItem>>((ref) {
  return FirebaseFirestore.instance.collection('inventory').snapshots().map((snapshot) {
    final list = snapshot.docs.map((doc) => InventoryItem.fromFirestore(doc.data(), doc.id)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });
});

final inventoryControllerProvider = Provider((ref) => InventoryController());

class InventoryController {
  final _db = FirebaseFirestore.instance;

  Future<void> addItem(String name, String location, int quantity, String unit, int threshold) async {
    final item = InventoryItem(
      id: '',
      name: name,
      location: location,
      quantity: quantity,
      unit: unit,
      lowStockThreshold: threshold,
    );
    await _db.collection('inventory').add(item.toMap());
  }

  Future<void> updateQuantity(String id, int currentQty, int delta) async {
    final newQty = (currentQty + delta).clamp(0, 999);
    await _db.collection('inventory').doc(id).update({'quantity': newQty});
  }

  Future<void> removeItem(String id) async {
    await _db.collection('inventory').doc(id).delete();
  }

  Future<void> restoreItem(InventoryItem item) async {
    await _db.collection('inventory').doc(item.id).set(item.toMap());
  }

  Future<void> updateItem(InventoryItem item) async {
    await _db.collection('inventory').doc(item.id).update(item.toMap());
  }

  /// Отмечает товар как купленный: поднимает запас до уровня выше порога.
  Future<void> restock(InventoryItem item) async {
    final target = item.lowStockThreshold * 2 > item.lowStockThreshold + 1
        ? item.lowStockThreshold * 2
        : item.lowStockThreshold + 1;
    if (target > item.quantity) {
      await _db.collection('inventory').doc(item.id).update({'quantity': target});
    }
  }

  /// Пополняет все товары из списка покупок одним батчем.
  Future<void> restockAll(List<InventoryItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      final target = item.lowStockThreshold * 2 > item.lowStockThreshold + 1
          ? item.lowStockThreshold * 2
          : item.lowStockThreshold + 1;
      if (target > item.quantity) batch.update(_db.collection('inventory').doc(item.id), {'quantity': target});
    }
    await batch.commit();
  }

  /// Массовый импорт из текстового списка покупок
  Future<int> bulkAddFromText(String rawText, List<InventoryItem> existingItems) async {
    final lines = rawText.split('\n');
    final batch = _db.batch();
    int processedCount = 0;

    // Регулярное выражение ищет: [Начало строки без маркеров] [Название] [- / – / — / :] [Число] [Ед. изм.]
    final regex = RegExp(r'^[\s\*\-\•\d\.]*(.+?)\s*[\–\-\—\:]\s*(\d+)\s*(.*)$');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final match = regex.firstMatch(trimmed);
      if (match != null) {
        final rawName = match.group(1)?.trim() ?? '';
        final qty = int.tryParse(match.group(2) ?? '1') ?? 1;
        var rawUnit = match.group(3)?.trim() ?? 'szt.';

        if (rawName.isEmpty) {
          continue;
        }
        if (rawUnit.isEmpty) {
          rawUnit = 'szt.';
        }

        // Проверяем, существует ли уже такой продукт в базе (без учета регистра)
        final existingIndex = existingItems.indexWhere(
          (item) => item.name.toLowerCase() == rawName.toLowerCase(),
        );

        if (existingIndex != -1) {
          // Продукт уже есть — увеличиваем количество
          final existing = existingItems[existingIndex];
          final docRef = _db.collection('inventory').doc(existing.id);
          batch.update(docRef, {
            'quantity': FieldValue.increment(qty),
          });
        } else {
          // Продукта нет — создаем новый документ и определяем категорию хранения
          final docRef = _db.collection('inventory').doc();
          final location = _guessLocation(rawName);
          final newItem = InventoryItem(
            id: docRef.id,
            name: rawName,
            location: location,
            quantity: qty,
            unit: rawUnit,
            lowStockThreshold: 1,
          );
          batch.set(docRef, newItem.toMap());
        }
        processedCount++;
      }
    }

    if (processedCount > 0) {
      await batch.commit();
    }
    return processedCount;
  }

  /// Автоматическая категоризация для польских и английских названий
  String _guessLocation(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('mrożon') || lower.contains('lody') || lower.contains('frozen') || lower.contains('ice cream')) {
      return 'Freezer';
    }

    if (lower.contains('proszek') || lower.contains('płyn do płukania') || lower.contains('detergent') ||
        lower.contains('softener') || lower.contains('kapsułki')) {
      return 'Laundry';
    }
    
    if (lower.contains('płyn') || lower.contains('ręcznik') || lower.contains('folia') || 
        lower.contains('mydło') || lower.contains('papier') || lower.contains('worki') ||
        lower.contains('soap') || lower.contains('paper') || lower.contains('bags')) {
      return 'Household';
    }
    
    if (lower.contains('parówki') || lower.contains('kurczak') || lower.contains('salami') || 
        lower.contains('ser') || lower.contains('masło') || lower.contains('jajka') || 
        lower.contains('śmietana') || lower.contains('mleko') || lower.contains('jogurt') ||
        lower.contains('mięso') || lower.contains('szynka') || lower.contains('milk') ||
        lower.contains('cheese') || lower.contains('butter') || lower.contains('eggs') || lower.contains('chicken')) {
      return 'Fridge';
    }
    
    return 'Pantry';
  }
}
