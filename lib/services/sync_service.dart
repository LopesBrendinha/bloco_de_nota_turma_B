import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de uma operação com a nuvem, para a tela saber o que mostrar.
class SyncReport {
  final bool success;
  final String message;

  const SyncReport.ok() : success = true, message = '';
  const SyncReport.failed(this.message) : success = false;
}

/// Mantém o SQLite (local) e o Firestore (nuvem) iguais.
///
/// Estratégia: "local primeiro".
///  - O app sempre lê e grava no SQLite, então funciona sem internet.
///  - Toda alteração local marca a nota com synced = false.
///  - Quando há conexão, as notas pendentes são enviadas e as notas
///    novas ou mais recentes da nuvem são baixadas.
///  - Em conflito (a mesma nota alterada em dois lugares), vale a de
///    updatedAt mais recente ("a última alteração vence").
///  - Enviar para a lixeira e restaurar são alterações comuns (mudam
///    o deletedAt). Só a exclusão definitiva remove o documento.
class SyncService {
  SyncService({DatabaseHelper? local, FirestoreService? remote})
    : _local = local ?? DatabaseHelper.instance,
      _remote = remote ?? FirestoreService();

  final DatabaseHelper _local;
  final FirestoreService _remote;

  bool _running = false;

  Future<SyncReport> sync(String uid) async {
    // Evita duas sincronizações ao mesmo tempo.
    if (_running) return const SyncReport.ok();
    _running = true;

    try {
      // 1) Estado atual da nuvem e do aparelho.
      final remoteNotes = await _remote.fetchNotes(uid);
      final remoteById = {for (final n in remoteNotes) n.id: n};

      final localNotes = await _local.getAllNotes(uid);
      final localById = {for (final n in localNotes) n.id: n};

      // 2) Enviar as alterações locais pendentes.
      for (final local in localNotes.where((n) => !n.synced)) {
        final remote = remoteById[local.id];

        // A versão da nuvem é mais nova: ela vence e será baixada no
        // passo 4. Não sobrescrevemos com a versão local antiga.
        if (remote != null && remote.updatedAt > local.updatedAt) continue;

        await _remote.saveNote(local);
        await _local.markAsSynced(local.id);
      }

      // 3) Notas que já estiveram na nuvem (synced) e não existem mais
      // lá foram excluídas definitivamente em outro aparelho.
      // Apagamos a cópia local para as duas bases ficarem iguais.
      for (final local in localNotes) {
        if (local.synced && !remoteById.containsKey(local.id)) {
          await _local.deleteNotePermanently(local.id);
        }
      }

      // 4) Baixar notas novas ou mais recentes da nuvem.
      for (final remote in remoteNotes) {
        final local = localById[remote.id];

        if (local == null || remote.updatedAt > local.updatedAt) {
          await _local.upsertNote(remote);
        }

        // Garante que a categoria da nota exista na lista local.
        await _local.insertCategory(uid, remote.category);
      }

      return const SyncReport.ok();
    } catch (error) {
      return _failure(error);
    } finally {
      _running = false;
    }
  }

  /// Exclusão definitiva de uma nota da lixeira.
  ///
  /// Primeiro apaga na nuvem e só depois no aparelho. Se for ao
  /// contrário, a nota apagada só localmente voltaria na próxima
  /// sincronização. Por isso, sem conexão, a exclusão não é feita.
  Future<SyncReport> deletePermanently(Note note) async {
    try {
      await _remote.deleteNote(note.uid, note.id);
      await _local.deleteNotePermanently(note.id);

      return const SyncReport.ok();
    } catch (error) {
      return _failure(
        error,
        offlineMessage:
            'Não foi possível excluir definitivamente agora. '
            'Conecte-se à internet e tente de novo.',
      );
    }
  }

  /// Converte um erro técnico em uma mensagem para o usuário.
  SyncReport _failure(Object error, {String? offlineMessage}) {
    final offline =
        offlineMessage ??
        'Sem conexão com a nuvem. As notas continuam salvas no aparelho '
            'e serão enviadas quando a conexão voltar.';

    if (error is TimeoutException) {
      return SyncReport.failed(offline);
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return const SyncReport.failed(
          'Sem permissão para acessar as notas na nuvem. '
          'Verifique as regras do Firestore e o login.',
        );
      }

      if (error.code == 'unavailable') {
        return SyncReport.failed(offline);
      }

      return SyncReport.failed('Erro na sincronização (${error.code}).');
    }

    return const SyncReport.failed(
      'Erro inesperado ao sincronizar. Suas notas locais estão seguras.',
    );
  }
}