/// Contrato dos registros que existem no SQLite e no Firestore.
abstract interface class Syncable {
  String get id;

  /// Momento da última alteração, em milissegundos.
  int get updatedAt;

  /// Valor de [updatedAt] na última vez que o registro ficou igual à nuvem.
  /// É null quando o registro ainda não chegou à nuvem.
  int? get syncedAt;
}

extension SyncableState on Syncable {
  /// Existe alteração local que a nuvem ainda não recebeu.
  bool get hasPendingChanges => syncedAt != updatedAt;

  /// O registro já esteve na nuvem alguma vez.
  bool get wasSynced => syncedAt != null;
}
