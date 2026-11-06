class Note {
  final String id; // id gerado localmente (o mesmo no SQLite e no Firestore)
  final String uid;
  final String title;
  final String content;
  final String category;
  final bool archived;
  final bool synced; // false = ainda não enviada ao Firestore
  final int updatedAt; // milissegundos desde 1970

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Pessoal',
    this.archived = false,
    this.synced = false,
    required this.updatedAt,
  });

  String get formattedDate {
    final d = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Note copyWith({
    String? title,
    String? content,
    String? category,
    bool? archived,
    bool? synced,
    int? updatedAt,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      archived: archived ?? this.archived,
      synced: synced ?? this.synced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------- SQLite ----------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'archived': archived ? 1 : 0,
      'synced': synced ? 1 : 0,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String,
      archived: map['archived'] == 1,
      synced: map['synced'] == 1,
      updatedAt: map['updatedAt'] as int,
    );
  }

  // ---------- Firestore ----------
  // O campo "synced" não vai para a nuvem: ele só existe no aparelho.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'archived': archived,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromFirestore(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      category: (map['category'] ?? 'Pessoal') as String,
      archived: (map['archived'] ?? false) as bool,
      synced: true,
      updatedAt: (map['updatedAt'] as num).toInt(),
    );
  }
}
