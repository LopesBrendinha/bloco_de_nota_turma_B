import 'dart:async';

import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Acesso ao Cloud Firestore. Estrutura:
///
///   users/{uid}/notes/{noteId}
///   users/{uid}/categories/{categoryId}
///
/// Cada usuário só enxerga a própria subárvore (ver firestore.rules).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Sem resposta nesse tempo, a operação é tratada como falha de conexão.
  static const timeout = Duration(seconds: 12);

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _db.collection('users').doc(uid).collection('categories');

  /// Lê direto do servidor (sem cache), para não confundir dado em cache
  /// com dado confirmado na nuvem.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notes(
      uid,
    ).get(const GetOptions(source: Source.server)).timeout(timeout);
    return _parse(snapshot, Note.fromFirestore);
  }

  Future<void> upsertNote(Note note) =>
      _notes(note.uid).doc(note.id).set(note.toFirestore()).timeout(timeout);

  Future<void> deleteNote(String uid, String id) =>
      _notes(uid).doc(id).delete().timeout(timeout);

  Future<List<NoteCategory>> fetchCategories(String uid) async {
    final snapshot = await _categories(
      uid,
    ).get(const GetOptions(source: Source.server)).timeout(timeout);
    return _parse(snapshot, NoteCategory.fromFirestore);
  }

  Future<void> upsertCategory(NoteCategory category) => _categories(
    category.uid,
  ).doc(category.id).set(category.toFirestore()).timeout(timeout);

  Future<void> deleteCategory(String uid, String id) =>
      _categories(uid).doc(id).delete().timeout(timeout);

  /// Documentos malformados são ignorados em vez de interromper a sincronização.
  List<T> _parse<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(String id, Map<String, dynamic> data) fromFirestore,
  ) {
    final items = <T>[];
    for (final doc in snapshot.docs) {
      try {
        items.add(fromFirestore(doc.id, doc.data()));
      } catch (e) {
        debugPrint('Documento ignorado (${doc.reference.path}): $e');
      }
    }
    return items;
  }
}
