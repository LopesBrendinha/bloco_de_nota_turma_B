class Note {
  /// UUID gerado no app. É o mesmo ID no SQLite e no Firestore,
  /// o que permite comparar e sincronizar as duas bases.
  final String id;
  final String uid;
  final String title;
  final String content;
  final String category;

  /// Datas em milissegundos desde 1970 (facilita ordenar e comparar).
  final int createdAt;
  final int updatedAt;

  /// Quando não é null, a nota está na lixeira.
  final int? deletedAt;

  /// false = existe alteração local que ainda não foi enviada ao Firestore.
  final bool synced;

  Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Geral',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.synced = false,
  });

  bool get isDeleted => deletedAt != null;

  /// Data de última alteração no formato dd/MM/aaaa HH:mm.
  String get date {
    final d = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Note copyWith({
    String? title,
    String? content,
    String? category,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    bool? synced,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      synced: synced ?? this.synced,
    );
  }

  /// Conversão para o SQLite (boolean vira 0/1).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'synced': synced ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: (map['category'] as String?) ?? 'Geral',
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      deletedAt: map['deletedAt'] as int?,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  /// Conversão para o Firestore. O campo "synced" não vai para a nuvem,
  /// pois só faz sentido localmente.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  /// Notas vindas da nuvem chegam já sincronizadas.
  factory Note.fromFirestore(String id, Map<String, dynamic> data) {
    return Note(
      id: id,
      uid: data['uid'] as String,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Geral',
      createdAt: data['createdAt'] as int,
      updatedAt: data['updatedAt'] as int,
      deletedAt: data['deletedAt'] as int?,
      synced: true,
    );
  }
}