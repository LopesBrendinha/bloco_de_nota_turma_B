/// Estado de sincronização de um registro local em relação ao Firestore.
enum SyncStatus {
  /// Igual ao que está na nuvem.
  synced('synced'),

  /// Criado ou alterado localmente, ainda não enviado.
  pendingUpsert('pending_upsert'),

  /// Excluído localmente; o documento remoto ainda precisa ser apagado.
  pendingDelete('pending_delete');

  const SyncStatus(this.value);

  final String value;

  static SyncStatus parse(String? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.pendingUpsert,
    );
  }
}

/// Contrato comum entre notas e categorias para o motor de sincronização.
abstract class SyncEntity {
  String get id;
  int get updatedAt;
  SyncStatus get syncStatus;
}
