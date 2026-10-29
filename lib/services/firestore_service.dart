import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import '../models/note_category.dart';

/// Erro de comunicação com o Firebase, já com uma mensagem para o usuário.
class RemoteException implements Exception {
  final String message;

  /// `true` quando o problema é de conexão (sem internet, servidor fora do ar,
  /// tempo esgotado). Nesses casos as alterações ficam pendentes no aparelho.
  final bool isConnectionError;

  RemoteException(this.message, {this.isConnectionError = false});

  @override
  String toString() => message;
}

/// Acesso ao Cloud Firestore.
///
/// Estrutura dos dados na nuvem:
/// ```
/// users/{uid}/notes/{remoteId}
/// users/{uid}/categories/{remoteId}
/// ```
/// Cada usuário só enxerga a própria pasta `users/{uid}` (ver
/// `firestore.rules`).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Tempo máximo de espera por uma resposta do servidor.
  static const timeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _db.collection('users').doc(uid).collection('categories');

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw RemoteException(
        'Sem resposta do servidor. Verifique sua conexão.',
        isConnectionError: true,
      );
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          throw RemoteException(
            'Sem conexão com o Firebase.',
            isConnectionError: true,
          );
        case 'permission-denied':
          throw RemoteException('Acesso negado pelas regras do Firebase.');
        case 'unauthenticated':
          throw RemoteException('Sessão expirada. Entre novamente.');
        default:
          throw RemoteException('Erro no Firebase (${e.code}).');
      }
    }
  }

  Future<List<Note>> fetchNotes(String uid) => _run(() async {
    // Source.server: força a leitura no servidor, para detectar falta de
    // conexão em vez de devolver um cache possivelmente desatualizado.
    final snap = await _notes(uid).get(const GetOptions(source: Source.server));
    return snap.docs.map((d) => Note.fromFirestore(d.id, d.data())).toList();
  });

  Future<void> saveNote(Note note) =>
      _run(() => _notes(note.uid).doc(note.remoteId).set(note.toFirestore()));

  Future<void> deleteNote(String uid, String remoteId) =>
      _run(() => _notes(uid).doc(remoteId).delete());

  Future<List<NoteCategory>> fetchCategories(String uid) => _run(() async {
    final snap = await _categories(
      uid,
    ).get(const GetOptions(source: Source.server));
    return snap.docs
        .map((d) => NoteCategory.fromFirestore(d.id, d.data()))
        .toList();
  });

  Future<void> saveCategory(NoteCategory category) => _run(
    () => _categories(
      category.uid,
    ).doc(category.remoteId).set(category.toFirestore()),
  );
}
