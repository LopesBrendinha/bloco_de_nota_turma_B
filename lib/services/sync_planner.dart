import '../models/syncable.dart';

/// Registro da nuvem que deve ser gravado no aparelho.
class RemoteUpdate<T extends Syncable> {
  final T remote;

  /// Versão local que será substituída. Null se o registro é novo aqui.
  final T? local;

  const RemoteUpdate(this.remote, this.local);
}

/// O que precisa ser feito para igualar o aparelho e a nuvem.
class SyncPlan<T extends Syncable> {
  /// Registros da nuvem que substituem ou criam a versão local.
  final List<RemoteUpdate<T>> saveLocally = [];

  /// Registros apagados em outro aparelho.
  final List<T> deleteLocally = [];

  /// Registros que a nuvem precisa receber.
  final List<T> push = [];

  /// Registros iguais nos dois lados, mas ainda marcados como pendentes.
  /// Acontece quando o envio chegou à nuvem e a confirmação não chegou aqui.
  final List<T> markSynced = [];
}

/// Compara o aparelho com a nuvem e decide o destino de cada registro.
///
/// É uma função pura, sem acesso a banco ou rede, e por isso é a parte mais
/// testada do projeto. As regras são:
///
/// - **Só um lado mudou:** a mudança é copiada para o outro lado.
/// - **Os dois lados mudaram:** vence o `updatedAt` mais recente
///   (*last write wins*).
/// - **Sumiu da nuvem:** se não há alteração local, foi apagado em outro
///   aparelho e também sai daqui. Se há alteração local, ele é reenviado,
///   para não perder um texto que o usuário acabou de editar.
/// - **Exclusão pendente:** a versão da nuvem é ignorada, pois está sendo
///   apagada nesta mesma sincronização.
SyncPlan<T> planSync<T extends Syncable>({
  required List<T> local,
  required List<T> remote,
  Set<String> pendingDeletions = const {},
}) {
  final plan = SyncPlan<T>();
  final localById = {for (final item in local) item.id: item};
  final remoteIds = <String>{};

  for (final remoteItem in remote) {
    remoteIds.add(remoteItem.id);
    if (pendingDeletions.contains(remoteItem.id)) continue;

    final localItem = localById[remoteItem.id];
    if (localItem == null) {
      plan.saveLocally.add(RemoteUpdate(remoteItem, null));
    } else if (localItem.updatedAt == remoteItem.updatedAt) {
      if (localItem.hasPendingChanges) plan.markSynced.add(localItem);
    } else if (!localItem.hasPendingChanges) {
      plan.saveLocally.add(RemoteUpdate(remoteItem, localItem));
    } else if (remoteItem.updatedAt == localItem.syncedAt) {
      plan.push.add(localItem);
    } else if (remoteItem.updatedAt > localItem.updatedAt) {
      plan.saveLocally.add(RemoteUpdate(remoteItem, localItem));
    } else {
      plan.push.add(localItem);
    }
  }

  for (final localItem in local) {
    if (remoteIds.contains(localItem.id)) continue;

    if (localItem.hasPendingChanges) {
      plan.push.add(localItem);
    } else {
      plan.deleteLocally.add(localItem);
    }
  }

  return plan;
}
