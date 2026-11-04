import '../services/remote_data_source.dart';

enum SyncState { idle, syncing, synced, failed }

/// Situação da sincronização, exibida na tela de notas.
class SyncStatus {
  final SyncState state;

  /// Alterações que ainda não chegaram à nuvem.
  final int pendingChanges;

  /// Momento da última sincronização completa, em milissegundos.
  final int? lastSyncAt;

  /// Motivo da falha, quando [state] é [SyncState.failed].
  final RemoteErrorKind? failure;

  const SyncStatus({
    this.state = SyncState.idle,
    this.pendingChanges = 0,
    this.lastSyncAt,
    this.failure,
  });

  bool get isSyncing => state == SyncState.syncing;
  bool get isOffline => failure == RemoteErrorKind.offline;
}
