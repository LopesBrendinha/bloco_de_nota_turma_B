import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/utils/text_normalizer.dart';

class Note implements SyncEntity {
  /// UUID gerado no aparelho. O mesmo id é usado no SQLite e como id do
  /// documento no Firestore, o que permite criar notas offline sem conflito.
  @override
  final String id;

  final String uid;
  final String title;
  final String content;
  final String? categoryId;

  /// Datas em milissegundos desde a época (UTC), fáceis de comparar e ordenar.
  final int createdAt;
  @override
  final int updatedAt;

  @override
  final SyncStatus syncStatus;

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  Note copyWith({
    String? title,
    String? content,
    String? categoryId,
    bool clearCategory = false,
    int? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Linha da tabela `notes` no SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'search_text': normalizeForSearch('$title\n$content'),
      'sync_status': syncStatus.value,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      categoryId: map['category_id'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: SyncStatus.parse(map['sync_status'] as String?),
    );
  }

  /// Documento em users/{uid}/notes/{id}. O estado de sincronização é
  /// exclusivo do aparelho e não vai para a nuvem.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromFirestore(String id, Map<String, dynamic> data) {
    return Note(
      id: id,
      uid: data['uid'] as String,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      createdAt: (data['createdAt'] as num).toInt(),
      updatedAt: (data['updatedAt'] as num).toInt(),
      syncStatus: SyncStatus.synced,
    );
  }
}
