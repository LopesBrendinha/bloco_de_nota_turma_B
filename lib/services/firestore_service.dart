import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Se o Firebase não responder nesse tempo, consideramos falha de conexão.
  static const Duration _timeout = Duration(seconds: 5);

  // Caminho das notas: usuarios/{uid}/notas/{id}
  CollectionReference<Map<String, dynamic>> _notesRef(String uid) {
    return _db.collection('usuarios').doc(uid).collection('notas');
  }

  Future<void> saveNote(Note note) async {
    await _notesRef(note.uid)
        .doc(note.id.toString())
        .set(note.toMap())
        .timeout(_timeout);
  }

  Future<void> deleteNote(String uid, int id) async {
    await _notesRef(uid).doc(id.toString()).delete().timeout(_timeout);
  }

  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notesRef(uid).get().timeout(_timeout);

    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Garante que o id seja int mesmo que o Firestore devolva num.
      data['id'] = (data['id'] as num).toInt();
      return Note.fromMap(data);
    }).toList();
  }
}