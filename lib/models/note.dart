import '../utils/date_utils.dart';
import '../utils/text_utils.dart';
import 'syncable.dart';

/// Valor interno do [Note.copyWith] para distinguir "não alterar" de "null".
const Object _keep = Object();

class Note implements Syncable {
  /// Limites repetidos em `firestore.rules`: o formulário bloqueia antes,
  /// para que a nuvem nunca recuse uma nota que o aparelho aceitou.
  static const int maxTitleLength = 300;
  static const int maxContentLength = 100000;

  @override
  final String id;
  final String uid;
  final String title;
  final String content;
  final String? categoryId;
  final int createdAt;
  @override
  final int updatedAt;

  /// Momento em que a nota foi para a lixeira. Null se ela está ativa.
  final int? trashedAt;
  @override
  final int? syncedAt;

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.trashedAt,
    this.syncedAt,
  });

  bool get isTrashed => trashedAt != null;

  /// Data da última alteração, pronta para exibir.
  String get date => formatDateTime(updatedAt);

  Note copyWith({
    String? title,
    String? content,
    Object? categoryId = _keep,
    int? updatedAt,
    Object? trashedAt = _keep,
    Object? syncedAt = _keep,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: identical(categoryId, _keep)
          ? this.categoryId
          : categoryId as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trashedAt: identical(trashedAt, _keep)
          ? this.trashedAt
          : trashedAt as int?,
      syncedAt: identical(syncedAt, _keep) ? this.syncedAt : syncedAt as int?,
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
      'trashed_at': trashedAt,
      'synced_at': syncedAt,
      'search_text': normalizeForSearch('$title\n$content'),
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
      trashedAt: map['trashed_at'] as int?,
      syncedAt: map['synced_at'] as int?,
    );
  }

  /// Documento `users/{uid}/notes/{id}` no Firestore.
  ///
  /// `syncedAt` e `search_text` não vão para a nuvem: o primeiro é o estado
  /// deste aparelho e o segundo pode ser recalculado.
  Map<String, dynamic> toRemoteMap() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'trashedAt': trashedAt,
    };
  }

  factory Note.fromRemoteMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      categoryId: map['categoryId'] as String?,
      createdAt: (map['createdAt'] as num).toInt(),
      updatedAt: (map['updatedAt'] as num).toInt(),
      trashedAt: (map['trashedAt'] as num?)?.toInt(),
    );
  }
}
