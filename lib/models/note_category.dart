import 'package:flutter/material.dart';

import 'sync_status.dart';

/// Categoria usada para organizar as notas (Estudos, Trabalho, Pessoal...).
///
/// Segue exatamente o mesmo desenho de [Note]: UUID compartilhado entre
/// SQLite e Firestore, marca de tempo para resolver conflitos e
/// [SyncStatus] para a fila de sincronização.
class NoteCategory {
  final int? localId;
  final String id;
  final String uid;
  final String name;

  /// Cor exibida nos chips e nos cartões, guardada como inteiro ARGB.
  final int colorValue;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;

  const NoteCategory({
    this.localId,
    required this.id,
    required this.uid,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  Color get color => Color(colorValue);

  NoteCategory copyWith({
    int? localId,
    String? id,
    String? uid,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return NoteCategory(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toLocalMap() {
    return {
      if (localId != null) 'local_id': localId,
      'id': id,
      'uid': uid,
      'name': name,
      'color': colorValue,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus.code,
    };
  }

  factory NoteCategory.fromLocalMap(Map<String, Object?> map) {
    return NoteCategory(
      localId: map['local_id'] as int?,
      id: map['id'] as String,
      uid: map['uid'] as String,
      name: (map['name'] as String?) ?? '',
      colorValue: (map['color'] as int?) ?? 0xFF6C4AB6,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      syncStatus: SyncStatus.fromCode(map['sync_status']),
    );
  }

  Map<String, Object?> toRemoteMap() {
    return {
      'uid': uid,
      'name': name,
      'color': colorValue,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory NoteCategory.fromRemoteMap(String id, Map<String, Object?> map) {
    return NoteCategory(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      colorValue: (map['color'] as int?) ?? 0xFF6C4AB6,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      syncStatus: SyncStatus.synced,
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value.toUtc();

    return DateTime.tryParse('$value')?.toUtc() ?? DateTime.now().toUtc();
  }
}
