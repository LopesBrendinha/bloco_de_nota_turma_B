import 'package:blocodenotasturmab/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comunicação com o Cloud Firestore.
///
/// Estrutura na nuvem: users/{uid}/notes/{idDaNota}
/// Qualquer falha (sem internet, sem permissão, tempo esgotado) vira exceção,
/// que é tratada pelo NoteRepository.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration _timeout = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> _notes(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  // Gera um id único sem precisar de internet.
  String newId() => _firestore.collection('users').doc().id;

  Future<void> saveNote(Note note) async {
    await _notes(note.uid).doc(note.id).set(note.toFirestore()).timeout(_timeout);
  }

  Future<void> deleteNote(String uid, String id) async {
    await _notes(uid).doc(id).delete().timeout(_timeout);
  }

  // Source.server força a leitura na nuvem: sem internet lança erro
  // (em vez de devolver silenciosamente o cache).
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notes(
      uid,
    ).get(const GetOptions(source: Source.server)).timeout(_timeout);

    return snapshot.docs.map((doc) => Note.fromFirestore(doc.data())).toList();
  }
}
