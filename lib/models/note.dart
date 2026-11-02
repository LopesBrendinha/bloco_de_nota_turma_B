class Note {
  final int? id;
  final String cloudId;
  final String uid;
  final String title;
  final String content;
  final String category;
  final int createdAt;
  final int updatedAt;
  final bool archived;
  final bool deleted;
  final bool synced;
  final String changeId;

  const Note({
    this.id,
    required this.cloudId,
    required this.uid,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.changeId,
    this.category = 'Pessoal',
    this.archived = false,
    this.deleted = false,
    this.synced = false,
  });

  String get date {
    final value = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(value.day)}/${pad(value.month)}/${value.year} '
        '${pad(value.hour)}:${pad(value.minute)}';
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    int? updatedAt,
    bool? archived,
    bool? deleted,
    bool? synced,
    String? changeId,
  }) => Note(
    id: id ?? this.id,
    cloudId: cloudId,
    uid: uid,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    deleted: deleted ?? this.deleted,
    synced: synced ?? this.synced,
    changeId: changeId ?? this.changeId,
  );

  Map<String, dynamic> toCloud() => {
    'uid': uid,
    'title': title,
    'content': content,
    'category': category,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archived': archived,
    'deleted': deleted,
    'changeId': changeId,
  };

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    ...toCloud(),
    'cloudId': cloudId,
    'date': date,
    'archived': archived ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'synced': synced ? 1 : 0,
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    cloudId: map['cloudId'] as String,
    uid: map['uid'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    category: map['category'] as String,
    createdAt: map['createdAt'] as int,
    updatedAt: map['updatedAt'] as int,
    archived: map['archived'] == 1,
    deleted: map['deleted'] == 1,
    synced: map['synced'] == 1,
    changeId: map['changeId'] as String,
  );

  factory Note.fromCloud(String cloudId, Map<String, dynamic> map) =>
      Note.fromMap({
        ...map,
        'cloudId': cloudId,
        'archived': map['archived'] == true ? 1 : 0,
        'deleted': map['deleted'] == true ? 1 : 0,
        'synced': 1,
      });
}
