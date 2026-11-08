class Note {
  final int? id;
  final String syncId; // mesmo ID no SQLite e no Firestore
  final String uid;
  final String title;
  final String content;
  final String category;
  final String date; // texto para exibição
  final String updatedAt; // ISO UTC, usado para ordenar e sincronizar
  final bool deleted; // true = na lixeira
  final bool synced; // true = já enviada ao Firestore

  Note({
    this.id,
    required this.syncId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Geral',
    required this.date,
    required this.updatedAt,
    this.deleted = false,
    this.synced = false,
  });

  Note copyWith({
    String? title,
    String? content,
    String? category,
    String? date,
    String? updatedAt,
    bool? deleted,
    bool? synced,
  }) {
    return Note(
      id: id,
      syncId: syncId,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'date': date,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'synced': synced ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      syncId: map['sync_id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      category: map['category'],
      date: map['date'],
      updatedAt: map['updated_at'],
      deleted: map['deleted'] == 1,
      synced: map['synced'] == 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'date': date,
      'updatedAt': updatedAt,
      'deleted': deleted,
    };
  }

  factory Note.fromFirestore(String id, Map<String, dynamic> data, String uid) {
    return Note(
      syncId: id,
      uid: uid,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'Geral',
      date: data['date'] ?? '',
      updatedAt: data['updatedAt'] ?? '',
      deleted: data['deleted'] == true,
      synced: true,
    );
  }
}
