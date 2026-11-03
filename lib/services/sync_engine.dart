import 'package:blocodenotasturmab/models/sync_status.dart';

/// Ponte entre um tipo de registro e os dois armazenamentos (Adapter).
/// O motor de sincronização só conhece esta interface, o que permite
/// sincronizar notas e categorias com o mesmo algoritmo e testá-lo sem
/// SQLite nem Firebase.
abstract class SyncAdapter<T extends SyncEntity> {
  Future<List<T>> localAll();

  /// Grava localmente uma versão vinda da nuvem (fica como `synced`).
  Future<void> applyRemote(T item);

  Future<void> markSynced(String id, int updatedAt);

  /// Apaga a linha local somente se ela ainda estiver em [onlyIf].
  Future<void> localRemove(String id, SyncStatus onlyIf);

  Future<List<T>> remoteAll();
  Future<void> remoteUpsert(T item);
  Future<void> remoteDelete(String id);
}

class SyncReport {
  int pulled = 0;
  int pushed = 0;
  int deletedRemotely = 0;
  int removedLocally = 0;

  /// Indica se a tela precisa recarregar a lista.
  bool get changedLocalData => pulled > 0 || removedLocally > 0;
}

/// Algoritmo de sincronização bidirecional:
///
/// 1. Baixa todos os documentos do usuário no Firestore.
/// 2. Para cada documento remoto:
///    - não existe localmente → é inserido;
///    - existe e está `synced` → a versão remota substitui a local;
///    - existe com alteração pendente → vence o `updatedAt` mais recente
///      (last-write-wins).
/// 3. Para cada registro local:
///    - `synced` e ausente na nuvem → foi excluído em outro aparelho, sai daqui;
///    - `pendingUpsert` → é enviado e marcado como `synced`;
///    - `pendingDelete` → é apagado no Firestore e depois no SQLite.
///
/// Qualquer exceção interrompe o processo; o que não foi confirmado continua
/// pendente e é reenviado na próxima tentativa (as operações são idempotentes).
class SyncEngine {
  const SyncEngine();

  Future<SyncReport> run(List<SyncAdapter> adapters) async {
    final report = SyncReport();
    for (final adapter in adapters) {
      await syncCollection(adapter, report);
    }
    return report;
  }

  Future<void> syncCollection<T extends SyncEntity>(
    SyncAdapter<T> adapter,
    SyncReport report,
  ) async {
    final remoteItems = await adapter.remoteAll();
    final localById = {
      for (final item in await adapter.localAll()) item.id: item,
    };
    final remoteIds = <String>{};

    for (final remote in remoteItems) {
      remoteIds.add(remote.id);
      final local = localById[remote.id];

      final remoteWins =
          local == null ||
          (local.syncStatus == SyncStatus.synced
              ? local.updatedAt != remote.updatedAt
              : remote.updatedAt > local.updatedAt);

      if (remoteWins) {
        await adapter.applyRemote(remote);
        localById[remote.id] = remote;
        report.pulled++;
      }
    }

    for (final local in localById.values) {
      switch (local.syncStatus) {
        case SyncStatus.synced:
          if (!remoteIds.contains(local.id)) {
            await adapter.localRemove(local.id, SyncStatus.synced);
            report.removedLocally++;
          }
        case SyncStatus.pendingUpsert:
          await adapter.remoteUpsert(local);
          await adapter.markSynced(local.id, local.updatedAt);
          report.pushed++;
        case SyncStatus.pendingDelete:
          if (remoteIds.contains(local.id)) {
            await adapter.remoteDelete(local.id);
            report.deletedRemotely++;
          }
          await adapter.localRemove(local.id, SyncStatus.pendingDelete);
      }
    }
  }
}
