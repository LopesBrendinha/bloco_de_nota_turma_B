class Note {
  // ID local, gerado pelo SQLite (AUTOINCREMENT).
  final int? id;

  // ID do documento no Firestore.
  //
  // O ID local não serve na nuvem, porque dois
  // aparelhos diferentes geram os mesmos números.
  final String? remoteId;

  final String uid;
  final String title;
  final String category;
  final String content;
  final String date;

  // Momento da última alteração, em milissegundos.
  final int updatedAt;

  // true  = a nota já foi enviada para o Firestore.
  // false = existe alteração pendente de envio.
  final bool synced;

  // Exclusão pendente: a nota foi apagada sem internet
  // e ainda precisa ser apagada no Firestore.
  final bool deleted;

  Note({
    this.id,
    this.remoteId,
    required this.uid,
    required this.title,
    required this.category,
    required this.content,
    required this.date,
    int? updatedAt,
    this.synced = false,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Note copyWith({
    int? id,
    String? remoteId,
    String? category,
    bool? synced,
    bool? deleted,
  }) {
    return Note(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      uid: uid,
      title: title,
      category: category ?? this.category,
      content: content,
      date: date,
      updatedAt: updatedAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }

  // Formato usado no banco local (SQLite).
  // O SQLite não tem tipo booleano, então usamos 0 e 1.
  Map<String, dynamic> toMap(){
    return{
      'id': id,
      'remote_id': remoteId,
      'uid' : uid,
      'title' : title,
      'category' : category,
      'content' : content,
      'date' : date,
      'updated_at': updatedAt,
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map){
    return Note(
      id: map['id'],
      remoteId: map['remote_id'],
      uid: map['uid'],
      title: map['title'],
      category: map['category'] ?? '',
      content: map['content'],
      date: map['date'],
      updatedAt: map['updated_at'] ?? 0,
      synced: map['synced'] == 1,
      deleted: map['deleted'] == 1,
    );
  }

  // Formato usado no Firestore.
  // Campos de controle local (id, synced, deleted) não vão para a nuvem.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'category': category,
      'content': content,
      'date': date,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromFirestore(String documentId, Map<String, dynamic> data) {
    return Note(
      remoteId: documentId,
      uid: data['uid'],
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      content: data['content'] ?? '',
      date: data['date'] ?? '',
      updatedAt: data['updatedAt'] ?? 0,
      synced: true,
    );
  }
}
