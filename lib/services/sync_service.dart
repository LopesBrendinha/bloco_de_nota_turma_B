import '../database/database_helper.dart';
import '../models/note.dart';
import 'firestore_service.dart';

/// O que fazer com uma nota quando comparamos a versão local com a da nuvem.
enum MergeAction { keepLocal, takeRemote, deleteLocal }

/// Regra de resolução de conflitos (função pura, coberta por testes).
///
/// - Nota local com alterações pendentes ou exclusão pendente: mantém a local,
///   a menos que a versão da nuvem seja mais nova (última gravação vence).
/// - Nota local sincronizada que não existe mais na nuvem: foi excluída em
///   outro aparelho, então é removida daqui também.
/// - Nota local sincronizada e diferente da nuvem: a nuvem vence.
MergeAction resolveMerge({required Note? local, required Note? remote}) {
  if (local == null) return MergeAction.takeRemote;

  if (remote == null) {
    return local.syncStatus == SyncStatus.synced
        ? MergeAction.deleteLocal
        : MergeAction.keepLocal;
  }

  if (local.syncStatus == SyncStatus.synced) {
    return remote.updatedAt == local.updatedAt &&
            remote.deletedAt == local.deletedAt
        ? MergeAction.keepLocal
        : MergeAction.takeRemote;
  }

  return remote.updatedAt.isAfter(local.updatedAt)
      ? MergeAction.takeRemote
      : MergeAction.keepLocal;
}

/// Resultado de uma sincronização, exibido na interface.
class SyncResult {
  final bool success;
  final bool isConnectionError;
  final String? message;
  final int uploaded;
  final int downloaded;

  const SyncResult.ok({this.uploaded = 0, this.downloaded = 0})
    : success = true,
      isConnectionError = false,
      message = null;

  const SyncResult.failed(this.message, {this.isConnectionError = false})
    : success = false,
      uploaded = 0,
      downloaded = 0;
}

/// Sincroniza o SQLite com o Firestore em duas etapas:
///
/// 1. **Envio (push):** tudo que está `pending` é gravado no Firestore e tudo
///    que está `pendingDelete` é excluído de lá. Só depois da confirmação do
///    servidor o registro local vira `synced` (ou é apagado de vez).
/// 2. **Recebimento (pull):** busca todas as notas e categorias do usuário na
///    nuvem e aplica [resolveMerge] em cada uma.
///
/// Se a conexão falhar no meio, nada se perde: o que não foi confirmado
/// continua pendente e é reenviado na próxima tentativa. Os envios usam o
/// mesmo ID de documento, então repetir um envio não duplica a nota.
class SyncService {
  SyncService({DatabaseHelper? local, FirestoreService? remote})
    : _local = local ?? DatabaseHelper.instance,
      _remote = remote ?? FirestoreService();

  final DatabaseHelper _local;
  final FirestoreService _remote;

  Future<SyncResult>? _running;

  /// Evita duas sincronizações ao mesmo tempo: quem chamar durante uma
  /// sincronização recebe o resultado da que já está em andamento.
  Future<SyncResult> sync(String uid) {
    return _running ??= _sync(uid).whenComplete(() => _running = null);
  }

  Future<SyncResult> _sync(String uid) async {
    try {
      final uploaded = await _push(uid);
      final downloaded = await _pull(uid);
      return SyncResult.ok(uploaded: uploaded, downloaded: downloaded);
    } on RemoteException catch (e) {
      return SyncResult.failed(
        e.message,
        isConnectionError: e.isConnectionError,
      );
    } catch (e) {
      return SyncResult.failed('Erro inesperado ao sincronizar: $e');
    }
  }

  Future<int> _push(String uid) async {
    var count = 0;

    for (final category in await _local.getUnsyncedCategories(uid)) {
      await _remote.saveCategory(category);
      await _local.markCategorySynced(category.remoteId);
      count++;
    }

    for (final note in await _local.getUnsyncedNotes(uid)) {
      if (note.syncStatus == SyncStatus.pendingDelete) {
        await _remote.deleteNote(uid, note.remoteId);
        await _local.deleteNote(note.remoteId);
      } else {
        await _remote.saveNote(note);
        await _local.markNoteSynced(note.remoteId, note.updatedAt);
      }
      count++;
    }
    return count;
  }

  Future<int> _pull(String uid) async {
    var count = 0;

    for (final category in await _remote.fetchCategories(uid)) {
      await _local.upsertCategory(category);
    }

    final remoteNotes = {
      for (final n in await _remote.fetchNotes(uid)) n.remoteId: n,
    };
    final localNotes = {
      for (final n in await _local.getAllNotes(uid)) n.remoteId: n,
    };

    final ids = {...remoteNotes.keys, ...localNotes.keys};
    for (final id in ids) {
      final local = localNotes[id];
      final remote = remoteNotes[id];
      switch (resolveMerge(local: local, remote: remote)) {
        case MergeAction.keepLocal:
          break;
        case MergeAction.takeRemote:
          await _local.upsertNote(remote!);
          count++;
        case MergeAction.deleteLocal:
          await _local.deleteNote(id);
          count++;
      }
    }
    return count;
  }
}
