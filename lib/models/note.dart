import 'dart:convert';

import 'checklist_item.dart';

class Note {
  static const defaultCategory = 'Sem categoria';

  final int? id;
  final String uid;
  final String title;
  final String content;
  final String date;
  final String category;
  final List<ChecklistItem> checklist;
  final String? remoteId;
  final bool pendingSync;
  final bool deleted;
  final int revision;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.date,
    this.category = defaultCategory,
    this.checklist = const [],
    this.remoteId,
    this.pendingSync = true,
    this.deleted = false,
    this.revision = 0,
  });

  Map<String, dynamic> toMap(){
    return{
      'id': id,
      'uid' : uid,
      'title' : title,
      'content' : content,
      'date' : date,
      'category': category,
      'checklist': jsonEncode(checklist.map((item) => item.toMap()).toList()),
      'remoteId': remoteId,
      'pendingSync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
      'revision': revision,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map){
    return Note(
      id: map['id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
      category: map['category'] ?? defaultCategory,
      checklist: (jsonDecode(map['checklist'] as String? ?? '[]') as List)
          .map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      remoteId: map['remoteId'],
      pendingSync: (map['pendingSync'] ?? 1) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
      revision: map['revision'] ?? 0,
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'uid': uid,
      'title': deleted ? '' : title,
      'content': deleted ? '' : content,
      'date': date,
      'category': deleted ? defaultCategory : category,
      'checklist': deleted
          ? []
          : checklist.map((item) => item.toMap()).toList(),
      'deleted': deleted,
    };
  }

  factory Note.fromCloud(String remoteId, Map<String, dynamic> map) {
    return Note(
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      date: map['date'] as String,
      category: map['category'] as String? ?? defaultCategory,
      checklist: (map['checklist'] as List? ?? [])
          .map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      remoteId: remoteId,
      pendingSync: false,
      deleted: map['deleted'] as bool,
    );
  }

  bool matchesSearch(String query) {
    final term = query.trim().toLowerCase();
    return title.toLowerCase().contains(term) ||
        content.toLowerCase().contains(term) ||
        checklist.any((item) => item.text.toLowerCase().contains(term));
  }

}
