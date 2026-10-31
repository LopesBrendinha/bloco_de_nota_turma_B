class Note {
  final int? id;
  final String uid;
  final String title;
  final String content;
  final String date;
  final String category;
  final String createdAt;
  final String updatedAt;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.date,
    this.category = 'Geral',
    this.createdAt = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'date': date,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
      category: map['category'] ?? 'Geral',
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
    );
  }
}