import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';

abstract class NotesCloud {
  Future<Note> send(Note note);
  Future<List<Note>> fetch(String uid);
}

class FirestoreService implements NotesCloud {
  final FirebaseFirestore firestore;
  FirestoreService({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      firestore.collection('users').doc(uid).collection('notes');

  @override
  Future<Note> send(Note note) => firestore.runTransaction(
    (transaction) async {
      final reference = _notes(note.uid).doc(note.cloudId);
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        final remote = Note.fromCloud(snapshot.id, snapshot.data()!);
        if (remote.updatedAt > note.updatedAt ||
            (remote.updatedAt == note.updatedAt &&
                remote.changeId.compareTo(note.changeId) > 0)) {
          return remote;
        }
      }
      transaction.set(reference, note.toCloud());
      return note.copyWith(synced: true);
    },
    timeout: const Duration(seconds: 10),
    maxAttempts: 2,
  );

  @override
  Future<List<Note>> fetch(String uid) async {
    final result = await _notes(
      uid,
    ).get(const GetOptions(source: Source.server));
    return result.docs
        .map((doc) => Note.fromCloud(doc.id, doc.data()))
        .toList();
  }
}
