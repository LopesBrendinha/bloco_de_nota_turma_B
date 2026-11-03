import 'package:blocodenotasturmab/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Acesso ao Cloud Firestore. Só conhece a nuvem: não sabe nada
/// do SQLite nem da lógica de sincronização.
///
/// Estrutura dos dados:
///   users/{uid}/notes/{noteId}
///
/// Colocar as notas dentro do documento do usuário deixa a regra de
/// segurança simples: só quem tem aquele uid acessa aquele caminho.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sem internet, o Firestore deixa a operação "pendurada" esperando
  /// a conexão voltar. O timeout transforma isso em erro, que o
  /// SyncService trata e usa para manter a nota como pendente.
  static const Duration _timeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _notes(String uid) {
    return _db.collection('users').doc(uid).collection('notes');
  }

  /// Cria ou substitui a nota na nuvem (mesmo ID do SQLite).
  Future<void> saveNote(Note note) {
    return _notes(note.uid)
        .doc(note.id)
        .set(note.toFirestore())
        .timeout(_timeout);
  }

  /// Baixa todas as notas do usuário, inclusive as da lixeira.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notes(uid).get().timeout(_timeout);

    return snapshot.docs
        .map((doc) => Note.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Remove o documento da nuvem (exclusão definitiva).
  Future<void> deleteNote(String uid, String id) {
    return _notes(uid).doc(id).delete().timeout(_timeout);
  }
}