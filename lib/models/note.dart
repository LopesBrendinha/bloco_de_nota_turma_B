import '../utils/text_normalizer.dart';
import 'sync_status.dart';

/// Representa uma nota do usuário.
///
/// O mesmo objeto é usado pelo SQLite e pelo Cloud Firestore, por isso
/// existem dois pares de conversores:
///
/// * [toLocalMap] / [Note.fromLocalMap]   -> colunas da tabela `notes`
/// * [toRemoteMap] / [Note.fromRemoteMap] -> documento `users/{uid}/notes/{id}`
///
/// O campo [id] é um UUID gerado no aplicativo e usado como **chave única
/// nos dois armazenamentos**. É ele que torna a sincronização possível:
/// sem um identificador compartilhado não há como saber se um documento da
/// nuvem corresponde a uma linha local.
class Note {
  /// Chave primária do SQLite (AUTOINCREMENT). Nula antes do primeiro insert.
  final int? localId;

  /// UUID compartilhado entre SQLite e Firestore.
  final String id;

  /// UID do usuário autenticado no Firebase Authentication.
  final String uid;

  final String title;
  final String content;

  /// [NoteCategory.id] da categoria associada, ou `null` para "sem categoria".
  final String? categoryId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// `true` quando a nota está na lixeira (exclusão temporária).
  final bool isDeleted;

  /// Momento em que a nota foi movida para a lixeira.
  final DateTime? deletedAt;

  final SyncStatus syncStatus;

  const Note({
    this.localId,
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  Note copyWith({
    int? localId,
    String? id,
    String? uid,
    String? title,
    String? content,
    String? categoryId,
    bool clearCategory = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Note(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite
  // ---------------------------------------------------------------------------

  Map<String, Object?> toLocalMap() {
    return {
      // `local_id` fica fora do mapa quando é nulo para o SQLite poder
      // gerar o AUTOINCREMENT.
      if (localId != null) 'local_id': localId,
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      // Coluna derivada: título + conteúdo em minúsculas e sem acentos.
      // É sobre ela que a pesquisa roda, para funcionar com acentuação.
      'search_text': TextNormalizer.forNote(title: title, content: content),
      'category_id': categoryId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus.code,
    };
  }

  factory Note.fromLocalMap(Map<String, Object?> map) {
    return Note(
      localId: map['local_id'] as int?,
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      categoryId: map['category_id'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: _parseNullableDate(map['deleted_at']),
      syncStatus: SyncStatus.fromCode(map['sync_status']),
    );
  }

  // ---------------------------------------------------------------------------
  // Cloud Firestore
  // ---------------------------------------------------------------------------

  /// Documento gravado em `users/{uid}/notes/{id}`.
  ///
  /// `sync_status` e `local_id` não são enviados: são detalhes do
  /// armazenamento local e não têm significado na nuvem.
  Map<String, Object?> toRemoteMap() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
  }

  factory Note.fromRemoteMap(String id, Map<String, Object?> map) {
    return Note(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      categoryId: map['categoryId'] as String?,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      deletedAt: _parseNullableDate(map['deletedAt']),
      // Acabou de chegar da nuvem, portanto está sincronizada.
      syncStatus: SyncStatus.synced,
    );
  }

  static DateTime _parseDate(Object? value) {
    return _parseNullableDate(value) ?? DateTime.now().toUtc();
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();

    return DateTime.tryParse('$value')?.toUtc();
  }
}
