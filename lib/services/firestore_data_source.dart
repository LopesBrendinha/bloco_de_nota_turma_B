import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import 'remote_data_source.dart';

/// Adapta o SDK do Cloud Firestore à interface [RemoteDataSource].
class FirestoreDataSource implements RemoteDataSource {
  /// Sem o cache do SDK, uma escrita feita sem internet não termina nem
  /// falha: ela fica esperando a conexão voltar. O limite de tempo devolve
  /// o controle para a sincronização, que tenta de novo depois.
  static const Duration _timeout = Duration(seconds: 15);

  final FirebaseFirestore _firestore;

  FirestoreDataSource(this._firestore);

  CollectionReference<Map<String, dynamic>> _notes(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  CollectionReference<Map<String, dynamic>> _categories(String uid) {
    return _firestore.collection('users').doc(uid).collection('categories');
  }

  @override
  Future<List<Note>> fetchNotes(String uid) {
    return _guard(() async {
      final snapshot = await _notes(
        uid,
      ).get(const GetOptions(source: Source.server));
      return _parse(snapshot, Note.fromRemoteMap);
    });
  }

  @override
  Future<void> saveNote(Note note) {
    return _guard(() {
      return _notes(note.uid).doc(note.id).set({
        ...note.toRemoteMap(),
        'serverUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteNote(String uid, String id) {
    return _guard(() => _notes(uid).doc(id).delete());
  }

  @override
  Future<List<NoteCategory>> fetchCategories(String uid) {
    return _guard(() async {
      final snapshot = await _categories(
        uid,
      ).get(const GetOptions(source: Source.server));
      return _parse(snapshot, NoteCategory.fromRemoteMap);
    });
  }

  @override
  Future<void> saveCategory(NoteCategory category) {
    return _guard(() {
      return _categories(category.uid).doc(category.id).set({
        ...category.toRemoteMap(),
        'serverUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteCategory(String uid, String id) {
    return _guard(() => _categories(uid).doc(id).delete());
  }

  /// Ignora documentos fora do formato esperado, como os criados à mão no
  /// console, para que um deles não impeça a leitura de todos os outros.
  List<T> _parse<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(String id, Map<String, dynamic> data) parse,
  ) {
    final items = <T>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(parse(doc.id, doc.data()));
      } on TypeError {
        continue;
      }
    }
    return items;
  }

  /// Aplica o limite de tempo e traduz os erros do SDK para [RemoteException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw const RemoteException(RemoteErrorKind.offline, 'timeout');
    } on FirebaseException catch (error) {
      throw RemoteException(_kindFor(error.code), error.code);
    }
  }

  RemoteErrorKind _kindFor(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
      case 'network-request-failed':
        return RemoteErrorKind.offline;
      case 'permission-denied':
        return RemoteErrorKind.permissionDenied;
      case 'unauthenticated':
        return RemoteErrorKind.unauthenticated;
      case 'resource-exhausted':
        return RemoteErrorKind.quotaExceeded;
      default:
        return RemoteErrorKind.unknown;
    }
  }
}
