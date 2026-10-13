import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

final usersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map(
    (snapshot) => snapshot.docs.map((doc) => AppUser.fromFirestore(doc.data(), doc.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name)),
  );
});

final usersControllerProvider = Provider((ref) => UsersController());

class UsersController {
  final _db = FirebaseFirestore.instance;

  Future<void> addUser(String name, String pinCode, Color color) async {
    final user = AppUser(id: '', name: name, pinCode: pinCode, color: color);
    await _db.collection('users').add(user.toMap());
  }

  /// Обновляет жильца. Задачи и транзакции связаны с жильцом по имени,
  /// поэтому при переименовании они обновляются тем же батчем.
  Future<void> updateUser(String id, String oldName, String newName, String newPin, {Color? color}) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(id), {
      'name': newName,
      'pinCode': newPin,
      if (color != null) 'color': color.toARGB32(),
    });
    if (oldName != newName) {
      for (final col in ['chores', 'budget_transactions']) {
        final snap = await _db.collection(col).where('assignee', isEqualTo: oldName).get();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'assignee': newName});
        }
      }
    }
    await batch.commit();
  }

  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }
}