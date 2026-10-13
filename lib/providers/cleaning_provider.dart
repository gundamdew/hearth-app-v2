import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chore.dart';

final _chores = FirebaseFirestore.instance.collection('chores');

final cleaningProvider = StreamProvider<List<Chore>>((ref) {
  return _chores.snapshots().map((snapshot) {
    final list = snapshot.docs.map((doc) => Chore.fromFirestore(doc.data(), doc.id)).toList();
    // Невыполненные сверху, затем по категории и имени
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final c = a.category.compareTo(b.category);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return list;
  });
});

final cleaningControllerProvider = Provider((ref) => CleaningController());

class CleaningController {
  final _db = FirebaseFirestore.instance;

  Future<void> addChore(String name, String category, String assignee) {
    return _chores.add(Chore(id: '', name: name, category: category, assignee: assignee).toMap());
  }

  Future<void> deleteChore(String id) => _chores.doc(id).delete();

  Future<void> restoreChore(Chore chore) => _chores.doc(chore.id).set(chore.toMap());

  Future<void> toggleStatus(String id, bool currentStatus) => _chores.doc(id).update({'isDone': !currentStatus});

  Future<void> changeAssignee(String id, String currentAssignee, List<String> users) async {
    if (users.isEmpty) return;
    final next = (users.indexOf(currentAssignee) + 1) % users.length;
    await _chores.doc(id).update({'assignee': users[next]});
  }

  /// Распределяет невыполненные задачи поровну с учётом уже выполненных.
  Future<void> balanceLoad(List<Chore> chores, List<String> users) async {
    if (users.isEmpty) return;
    final load = {for (final u in users) u: chores.where((c) => c.isDone && c.assignee == u).length};
    final batch = _db.batch();
    for (final chore in chores.where((c) => !c.isDone)) {
      final lightest = users.reduce((a, b) => load[a]! <= load[b]! ? a : b);
      load[lightest] = load[lightest]! + 1;
      if (chore.assignee != lightest) batch.update(_chores.doc(chore.id), {'assignee': lightest});
    }
    await batch.commit();
  }

  /// Сбрасывает галочки и передаёт каждую задачу следующему жильцу.
  Future<void> swapAndNewWeek(List<Chore> chores, List<String> users) async {
    if (users.isEmpty) return;
    final batch = _db.batch();
    for (final chore in chores) {
      final i = users.indexOf(chore.assignee);
      final next = i == -1 ? 0 : (i + 1) % users.length;
      batch.update(_chores.doc(chore.id), {'assignee': users[next], 'isDone': false});
    }
    await batch.commit();
  }
}
