class Chore {
  final String id;
  final String name;
  final String category;
  final String assignee;
  final bool isDone;

  Chore({
    required this.id,
    required this.name,
    required this.category,
    required this.assignee,
    this.isDone = false,
  });

  Chore copyWith({
    String? id,
    String? name,
    String? category,
    String? assignee,
    bool? isDone,
  }) {
    return Chore(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      assignee: assignee ?? this.assignee,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'assignee': assignee,
      'isDone': isDone,
    };
  }

  factory Chore.fromFirestore(Map<String, dynamic> map, String documentId) {
    return Chore(
      id: documentId,
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      assignee: map['assignee'] ?? '',
      isDone: map['isDone'] ?? false,
    );
  }
}