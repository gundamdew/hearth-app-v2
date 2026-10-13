class InventoryItem {
  final String id;
  final String name;
  final String location;
  final int quantity;
  final String unit;
  final int lowStockThreshold;

  InventoryItem({
    required this.id,
    required this.name,
    required this.location,
    required this.quantity,
    required this.unit,
    required this.lowStockThreshold,
  });

  bool get isRunningLow => quantity <= lowStockThreshold;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? location,
    int? quantity,
    String? unit,
    int? lowStockThreshold,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'quantity': quantity,
      'unit': unit,
      'lowStockThreshold': lowStockThreshold,
    };
  }

  factory InventoryItem.fromFirestore(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId,
      name: map['name'] ?? '',
      location: map['location'] ?? 'General',
      quantity: map['quantity']?.toInt() ?? 0,
      unit: map['unit'] ?? 'pcs',
      lowStockThreshold: map['lowStockThreshold']?.toInt() ?? 1,
    );
  }
}