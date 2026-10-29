import '../utils/id_generator.dart';

/// Estado de sincronização de um registro local em relação ao Firestore.
enum SyncStatus {
  /// Igual ao que está na nuvem.
  synced,

  /// Criado ou alterado localmente e ainda não enviado.
  pending,

  /// Excluído definitivamente no aparelho; falta excluir na nuvem.
  pendingDelete;

  static SyncStatus fromName(String? name) => SyncStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => SyncStatus.pending,
  );
}

/// Modelo de nota usado em todo o app.
///
/// - [id]: chave do SQLite (só existe no aparelho).
/// - [remoteId]: chave do documento no Firestore. É gerada no aparelho no
///   momento da criação, por isso a nota tem o mesmo identificador nos dois
///   armazenamentos, mesmo quando criada sem internet.
/// - [deletedAt]: quando preenchido, a nota está na lixeira.
class Note {
  final int? id;
  final String remoteId;
  final String uid;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  Note({
    this.id,
    String? remoteId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = defaultCategory,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  }) : remoteId = remoteId ?? generateId();

  static const String defaultCategory = 'Geral';

  bool get isInTrash => deletedAt != null;

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Note(
      id: id ?? this.id,
      remoteId: remoteId,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ---------- SQLite ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remote_id': remoteId,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus.name,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: (map['category'] as String?) ?? defaultCategory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
      syncStatus: SyncStatus.fromName(map['sync_status'] as String?),
    );
  }

  // ---------- Firestore ----------

  /// Campos gravados no documento `users/{uid}/notes/{remoteId}`.
  /// Os campos locais (`id`, `sync_status`) não vão para a nuvem.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory Note.fromFirestore(String docId, Map<String, dynamic> data) {
    return Note(
      remoteId: docId,
      uid: data['uid'] as String,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      category: (data['category'] as String?) ?? defaultCategory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updatedAt'] as num).toInt(),
      ),
      deletedAt: data['deletedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (data['deletedAt'] as num).toInt(),
            ),
      syncStatus: SyncStatus.synced,
    );
  }
}
