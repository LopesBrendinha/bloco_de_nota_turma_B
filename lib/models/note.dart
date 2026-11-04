import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class Note {
  static const defaultCategory = 'Geral';
  static const defaultCategories = ['Geral', 'Estudos', 'Trabalho', 'Pessoal'];

  final int? id; // chave local (SQLite)
  final String remoteId; // id do documento no Firestore, igual em todas as instalações
  final String uid;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool trashed; // está na lixeira
  final bool synced; // local: false = alteração ainda não enviada à nuvem
  final bool purged; // local: excluída definitivamente, aguardando remoção na nuvem

  Note({
    this.id,
    required this.remoteId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = defaultCategory,
    required this.createdAt,
    required this.updatedAt,
    this.trashed = false,
    this.synced = false,
    this.purged = false,
  });

  factory Note.create({
    required String uid,
    required String title,
    required String content,
    String category = defaultCategory,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    return Note(
      remoteId: const Uuid().v4(),
      uid: uid,
      title: title,
      content: content,
      category: category,
      createdAt: date,
      updatedAt: date,
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    DateTime? updatedAt,
    bool? trashed,
    bool? synced,
    bool? purged,
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
      trashed: trashed ?? this.trashed,
      synced: synced ?? this.synced,
      purged: purged ?? this.purged,
    );
  }

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
      'trashed': trashed ? 1 : 0,
      'synced': synced ? 1 : 0,
      'purged': purged ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      trashed: map['trashed'] == 1,
      synced: map['synced'] == 1,
      purged: map['purged'] == 1,
    );
  }

  // Só os campos que pertencem à nuvem; flags locais (synced/purged) não sobem.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(
        createdAt.millisecondsSinceEpoch,
      ),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(
        updatedAt.millisecondsSinceEpoch,
      ),
      'trashed': trashed,
    };
  }

  factory Note.fromFirestore(String docId, Map<String, dynamic> data) {
    return Note(
      remoteId: docId,
      uid: data['uid'] as String,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      category: data['category'] as String? ?? defaultCategory,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      trashed: data['trashed'] as bool? ?? false,
      synced: true,
    );
  }

  String get formattedDate {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = updatedAt;
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
