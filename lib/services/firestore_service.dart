import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  FirestoreService({FirebaseFirestore? firestore, Duration? timeout})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _timeout = timeout ?? const Duration(seconds: 10);

  final FirebaseFirestore _firestore;

  /// Tempo máximo de espera por uma operação remota.
  ///
  /// É o que impede a interface de travar quando o servidor não responde —
  /// ver a explicação em [guard].
  final Duration _timeout;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  // ---------------------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------------------

  /// Cria ou substitui o documento da nota. O UUID local é o ID do documento.
  Future<void> upsertNote(Note note) async {
    await guard(
      () => _notes(note.uid).doc(note.id).set(note.toRemoteMap()),
      'Não foi possível salvar a nota na nuvem.',
    );
  }

  Future<void> deleteNote({required String uid, required String id}) async {
    await guard(
      () => _notes(uid).doc(id).delete(),
      'Não foi possível excluir a nota na nuvem.',
    );
  }

  /// Baixa todas as notas do usuário, inclusive as que estão na lixeira.
  ///
  /// A lixeira é um campo (`isDeleted`), não uma ausência de documento, por
  /// isso ela também precisa ser recuperada: é o que faz uma nota arquivada
  /// em um aparelho continuar na lixeira em outro.
  ///
  /// A leitura exige [Source.server]. Por padrão o Firestore cai no cache
  /// local quando não alcança o servidor e devolve um resultado **vazio sem
  /// erro** — que o repositório interpretaria como "a nuvem não tem mais
  /// essas notas" e apagaria as linhas locais já sincronizadas. Forçando a
  /// origem, a falta de conexão vira uma exceção e a sincronização é
  /// abortada sem destruir nada.
  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await guard(
      () => _notes(uid).get(const GetOptions(source: Source.server)),
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
    await guard(
      () => _categories(category.uid)
          .doc(category.id)
          .set(category.toRemoteMap()),
      'Não foi possível salvar a categoria na nuvem.',
    );
  }

  Future<void> deleteCategory({required String uid, required String id}) async {
    await guard(
      () => _categories(uid).doc(id).delete(),
      'Não foi possível excluir a categoria na nuvem.',
    );
  }

  /// Baixa as categorias do usuário. Como em [fetchNotes], a leitura vem
  /// obrigatoriamente do servidor.
  Future<List<NoteCategory>> fetchCategories(String uid) async {
    final snapshot = await guard(
      () => _categories(uid).get(const GetOptions(source: Source.server)),
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
  /// ## Por que existe um timeout
  ///
  /// O SDK do Firestore **não lança erro** quando não consegue falar com o
  /// servidor: ele grava a operação no próprio cache e fica retentando
  /// indefinidamente. O `Future` devolvido por `set()` ou `delete()` só
  /// completa quando o servidor confirma — ou seja, **nunca**, enquanto
  /// durar o problema.
  ///
  /// Sem o timeout, um `await` aqui trava a tela para sempre: foi o que
  /// aconteceu com o projeto sem a API do Firestore ativada, em que a lista
  /// simplesmente deixava de responder em vez de avisar o usuário.
  ///
  /// Estourado o prazo, a operação é tratada como falta de conexão: ela
  /// continua marcada como pendente no SQLite e será reenviada depois. Como
  /// toda gravação é um `set()` sobre um ID fixo, reenviar é inofensivo
  /// mesmo que a tentativa anterior acabe chegando ao servidor.
  ///
  /// Os casos tratados:
  ///
  /// * `unavailable` / `deadline-exceeded` -> sem internet ou servidor fora
  ///   do ar. É recuperável, então a operação continua pendente no SQLite.
  /// * `permission-denied` -> as regras de segurança recusaram o acesso
  ///   (por exemplo, tentativa de ler dados de outro usuário).
  /// * qualquer outro -> mensagem genérica, sem vazar detalhes do SDK.
  @visibleForTesting
  Future<T> guard<T>(Future<T> Function() action, String fallbackMessage) async {
    try {
      return await action().timeout(_timeout);
    } on TimeoutException {
      throw CloudException(
        'O Firebase não respondeu a tempo. Suas alterações foram salvas no '
        'aparelho e serão enviadas na próxima sincronização.',
        isOffline: true,
        code: 'timeout',
      );
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
            'Acesso negado pelo Firebase. Verifique se a API do Cloud '
            'Firestore está ativada no projeto e se as regras de segurança '
            'foram publicadas.',
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
