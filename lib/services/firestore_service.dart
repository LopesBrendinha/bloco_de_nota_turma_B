import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';
import '../models/note_category.dart';

/// Erro de acesso à nuvem já traduzido para uma mensagem em português.
///
/// O restante do aplicativo não precisa conhecer `FirebaseException` nem os
/// códigos do SDK: todas as falhas chegam como [CloudException], com
/// [isOffline] indicando se vale a pena tentar de novo mais tarde.
class CloudException implements Exception {
  CloudException(this.message, {this.isOffline = false, this.code});

  final String message;
  final bool isOffline;
  final String? code;

  @override
  String toString() => 'CloudException($code): $message';
}

/// Camada de acesso ao Cloud Firestore.
///
/// Estrutura dos dados na nuvem:
///
/// ```text
/// users/{uid}/notes/{noteId}
/// users/{uid}/categories/{categoryId}
/// ```
///
/// Guardar as notas **dentro** do documento do usuário é o que permite
/// escrever regras de segurança simples e à prova de erro: basta comparar
/// `{uid}` do caminho com `request.auth.uid`. Nenhuma consulta consegue
/// alcançar a subcoleção de outro usuário.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  // ---------------------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------------------

  /// Cria ou substitui o documento da nota. O UUID local é o ID do documento.
  Future<void> upsertNote(Note note) async {
    await _guard(
      () => _notes(note.uid).doc(note.id).set(note.toRemoteMap()),
      'Não foi possível salvar a nota na nuvem.',
    );
  }

  Future<void> deleteNote({required String uid, required String id}) async {
    await _guard(
      () => _notes(uid).doc(id).delete(),
      'Não foi possível excluir a nota na nuvem.',
    );
  }

  /// Baixa todas as notas do usuário, inclusive as que estão na lixeira.
  ///
  /// A lixeira é um campo (`isDeleted`), não uma ausência de documento, por
  /// isso ela também precisa ser recuperada: é o que faz uma nota arquivada
  /// em um aparelho continuar na lixeira em outro.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _guard(
      () => _notes(uid).get(),
      'Não foi possível baixar as notas da nuvem.',
    );

    return snapshot.docs
        .map((doc) => Note.fromRemoteMap(doc.id, doc.data()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------------------

  Future<void> upsertCategory(NoteCategory category) async {
    await _guard(
      () => _categories(category.uid)
          .doc(category.id)
          .set(category.toRemoteMap()),
      'Não foi possível salvar a categoria na nuvem.',
    );
  }

  Future<void> deleteCategory({required String uid, required String id}) async {
    await _guard(
      () => _categories(uid).doc(id).delete(),
      'Não foi possível excluir a categoria na nuvem.',
    );
  }

  Future<List<NoteCategory>> fetchCategories(String uid) async {
    final snapshot = await _guard(
      () => _categories(uid).get(),
      'Não foi possível baixar as categorias da nuvem.',
    );

    return snapshot.docs
        .map((doc) => NoteCategory.fromRemoteMap(doc.id, doc.data()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Tratamento de erros
  // ---------------------------------------------------------------------------

  /// Executa a chamada ao Firestore convertendo qualquer falha em
  /// [CloudException].
  ///
  /// Os três casos tratados:
  ///
  /// * `unavailable` / `deadline-exceeded` -> sem internet ou servidor fora
  ///   do ar. É recuperável, então a operação continua pendente no SQLite.
  /// * `permission-denied` -> as regras de segurança recusaram o acesso
  ///   (por exemplo, tentativa de ler dados de outro usuário).
  /// * qualquer outro -> mensagem genérica, sem vazar detalhes do SDK.
  Future<T> _guard<T>(Future<T> Function() action, String fallbackMessage) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          throw CloudException(
            'Sem conexão com o Firebase. Suas alterações foram salvas no '
            'aparelho e serão enviadas quando a internet voltar.',
            isOffline: true,
            code: error.code,
          );

        case 'permission-denied':
          throw CloudException(
            'Acesso negado pelas regras de segurança do Firebase. '
            'Entre novamente na sua conta e tente de novo.',
            code: error.code,
          );

        case 'unauthenticated':
          throw CloudException(
            'Sessão expirada. Faça login novamente para sincronizar.',
            code: error.code,
          );

        default:
          throw CloudException(
            '$fallbackMessage (${error.code})',
            code: error.code,
          );
      }
    } catch (error) {
      // Timeout, erro de plataforma, JSON inesperado: tratado como falha
      // recuperável para não perder a operação pendente.
      throw CloudException(fallbackMessage, isOffline: true);
    }
  }
}
