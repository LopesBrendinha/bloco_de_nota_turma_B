import 'package:blocodenotasturmab/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Contrato da fonte remota. O repositório depende desta abstração,
/// o que permite trocar o Firestore por um fake nos testes.
abstract class NoteRemoteDataSource {
  Future<void> upsert(Note note);
  Future<void> delete(String uid, String remoteId);
  Future<List<Note>> fetchAll(String uid);
}

class FirestoreNoteRemote implements NoteRemoteDataSource {
  final FirebaseFirestore _db;
  final Duration timeout;

  FirestoreNoteRemote({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 8),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  // Estrutura: users/{uid}/notes/{remoteId} — casa com as regras em firestore.rules.
  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  // O timeout evita que a operação fique pendurada sem internet;
  // a exceção é tratada no repositório, que mantém a nota como pendente.
  @override
  Future<void> upsert(Note note) =>
      _notes(note.uid).doc(note.remoteId).set(note.toFirestore()).timeout(timeout);

  @override
  Future<void> delete(String uid, String remoteId) =>
      _notes(uid).doc(remoteId).delete().timeout(timeout);

  @override
  Future<List<Note>> fetchAll(String uid) async {
    // Source.server: força leitura da nuvem, para não confundir cache com dado real.
    final snap = await _notes(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    return snap.docs.map((d) => Note.fromFirestore(d.id, d.data())).toList();
  }
}
