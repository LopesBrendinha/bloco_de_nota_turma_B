/// Estado de sincronização de um registro local em relação ao Firestore.
///
/// O banco local (SQLite) é sempre a fonte de verdade para a interface.
/// Cada linha guarda, além dos dados, qual operação ainda precisa ser
/// replicada para a nuvem. Isso é o que permite o aplicativo funcionar
/// offline: a gravação local nunca falha e a operação remota fica
/// pendente até existir conexão.
enum SyncStatus {
  /// Local e nuvem estão iguais.
  synced(0),

  /// Precisa ser criado/atualizado no Firestore.
  pendingUpsert(1),

  /// Precisa ser removido definitivamente do Firestore.
  pendingDelete(2);

  const SyncStatus(this.code);

  /// Valor inteiro gravado na coluna `sync_status` do SQLite.
  final int code;

  static SyncStatus fromCode(Object? code) {
    final value = code is int ? code : int.tryParse('$code') ?? 0;

    return SyncStatus.values.firstWhere(
      (status) => status.code == value,
      orElse: () => SyncStatus.synced,
    );
  }
}
