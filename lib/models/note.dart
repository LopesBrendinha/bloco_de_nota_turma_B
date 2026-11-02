import 'dart:math';

class Note {
  final int? id;
  final String remoteId;
  final String uid;
  final String title;
  final String content;
  final String category;
  final int createdAt;
  final int updatedAt;
  final bool archived;
  final bool deleted;
  final bool pendingSync;

  const Note({
    this.id,
    required this.remoteId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Pessoal',
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.deleted = false,
    this.pendingSync = true,
  });

  // O mesmo identificador acompanha a nota em todas as instalações.
  static String newRemoteId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String get date {
    final value = DateTime.fromMicrosecondsSinceEpoch(updatedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    int? updatedAt,
    bool? archived,
    bool? deleted,
    bool? pendingSync,
  }) => Note(
    id: id ?? this.id,
    remoteId: remoteId,
    uid: uid,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    deleted: deleted ?? this.deleted,
    pendingSync: pendingSync ?? this.pendingSync,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'remoteId': remoteId,
    'uid': uid,
    'title': title,
    'content': content,
    'date': date,
    'category': category,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archived': archived ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'pendingSync': pendingSync ? 1 : 0,
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    remoteId: map['remoteId'] as String,
    uid: map['uid'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    category: map['category'] as String,
    createdAt: map['createdAt'] as int,
    updatedAt: map['updatedAt'] as int,
    archived: map['archived'] == 1,
    deleted: map['deleted'] == 1,
    pendingSync: map['pendingSync'] == 1,
  );

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'title': title,
    'content': content,
    'category': category,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archived': archived,
    'deleted': deleted,
  };

  factory Note.fromFirestore(String remoteId, Map<String, dynamic> data) =>
      Note(
        remoteId: remoteId,
        uid: data['uid'] as String,
        title: data['title'] as String,
        content: data['content'] as String,
        category: data['category'] as String,
        createdAt: data['createdAt'] as int,
        updatedAt: data['updatedAt'] as int,
        archived: data['archived'] as bool,
        deleted: data['deleted'] as bool,
        pendingSync: false,
      );
}
