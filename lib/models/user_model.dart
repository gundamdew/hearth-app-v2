import 'package:flutter/material.dart';

class AppUser {
  final String id;
  final String name;
  final String pinCode;
  final Color color;

  AppUser({
    required this.id,
    required this.name,
    required this.pinCode,
    required this.color,
  });

  AppUser copyWith({String? id, String? name, String? pinCode, Color? color}) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      pinCode: pinCode ?? this.pinCode,
      color: color ?? this.color,
    );
  }

  // Для отправки в Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pinCode': pinCode,
      'color': color.toARGB32(),
    };
  }

  // Для чтения из Firebase
  factory AppUser.fromFirestore(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      name: map['name'] ?? 'Unknown',
      pinCode: map['pinCode'] ?? '0000',
      // ignore: deprecated_member_use
      color: Color(map['color'] ?? 0xFFB3C5B8), 
    );
  }
}