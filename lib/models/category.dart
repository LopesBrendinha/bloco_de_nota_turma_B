import 'package:blocodenotasturmab/models/sync_status.dart';

class NoteCategory implements SyncEntity {
  @override
  final String id;

  final String uid;
  final String name;

  /// Índice na [CategoryPalette].
  final int color;

  final int createdAt;
  @override
  final int updatedAt;

  @override
  final SyncStatus syncStatus;

  const NoteCategory({
    required this.id,
    required this.uid,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  NoteCategory copyWith({
    String? name,
    int? color,
    int? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return NoteCategory(
      id: id,
      uid: uid,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'color': color,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus.value,
    };
  }

  factory NoteCategory.fromMap(Map<String, dynamic> map) {
    return NoteCategory(
      id: map['id'] as String,
      uid: map['uid'] as String,
      name: map['name'] as String,
      color: map['color'] as int,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: SyncStatus.parse(map['sync_status'] as String?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'color': color,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory NoteCategory.fromFirestore(String id, Map<String, dynamic> data) {
    return NoteCategory(
      id: id,
      uid: data['uid'] as String,
      name: data['name'] as String? ?? 'Sem nome',
      color: (data['color'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as num).toInt(),
      updatedAt: (data['updatedAt'] as num).toInt(),
      syncStatus: SyncStatus.synced,
    );
  }
}
