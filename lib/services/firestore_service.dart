import 'package:blocodenotasturmab/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _timeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _notesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  String newId(String uid) {
    return _notesRef(uid).doc().id;
  }

  Future<void> saveNote(Note note) async {
    await _notesRef(note.uid)
        .doc(note.remoteId)
        .set(note.toFirestore())
        .timeout(_timeout);
  }

  Future<void> deleteNote(Note note) async {
    await _notesRef(note.uid)
        .doc(note.remoteId)
        .delete()
        .timeout(_timeout);
  }

  Future<List<Note>> getNotes(String uid) async {
    final snapshot = await _notesRef(uid)
      .get(const GetOptions(source: Source.server))
      .timeout(_timeout);

    return snapshot.docs
      .map((doc) => Note.fromFirestore(doc.id, doc.data()))
      .toList();
  }
}