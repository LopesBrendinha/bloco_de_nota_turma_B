import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

class FirestoreService {
  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes');

  Future<Note> saveNote(Note note) async {
    final reference = _notes(note.uid).doc(note.remoteId);
    // Transações falham sem conexão: nesse caso, a fila continua no SQLite.
    return FirebaseFirestore.instance.runTransaction(
      (transaction) async {
        final snapshot = await transaction.get(reference);
        if (snapshot.exists) {
          final remote = Note.fromFirestore(snapshot.id, snapshot.data()!);
          // A exclusão é definitiva; uma edição antiga não recria a nota.
          if (remote.deleted ||
              (!note.deleted && remote.updatedAt >= note.updatedAt)) {
            return remote;
          }
        }
        transaction.set(reference, note.toFirestore());
        return note.copyWith(pendingSync: false);
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 2,
    );
  }

  Future<List<Note>> getNotes(String uid) async {
    // Não confirmar sincronização usando apenas o cache do Firebase.
    final snapshot = await _notes(
      uid,
    ).get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => Note.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
