import '../utils/id_generator.dart';
import 'note.dart';

/// Categoria criada pelo usuário para organizar as notas.
///
/// As categorias padrão ([defaults]) existem para todos e não são gravadas
/// no banco; só as categorias personalizadas são salvas no SQLite e no
/// Firestore (`users/{uid}/categories/{remoteId}`).
class NoteCategory {
  final int? id;
  final String remoteId;
  final String uid;
  final String name;
  final SyncStatus syncStatus;

  NoteCategory({
    this.id,
    String? remoteId,
    required this.uid,
    required this.name,
    this.syncStatus = SyncStatus.pending,
  }) : remoteId = remoteId ?? generateId();

  static const List<String> defaults = [
    Note.defaultCategory,
    'Estudos',
    'Trabalho',
    'Pessoal',
  ];

  Map<String, dynamic> toMap() => {
    'id': id,
    'remote_id': remoteId,
    'uid': uid,
    'name': name,
    'sync_status': syncStatus.name,
  };

  factory NoteCategory.fromMap(Map<String, dynamic> map) => NoteCategory(
    id: map['id'] as int?,
    remoteId: map['remote_id'] as String,
    uid: map['uid'] as String,
    name: map['name'] as String,
    syncStatus: SyncStatus.fromName(map['sync_status'] as String?),
  );

  Map<String, dynamic> toFirestore() => {'uid': uid, 'name': name};

  factory NoteCategory.fromFirestore(String docId, Map<String, dynamic> data) =>
      NoteCategory(
        remoteId: docId,
        uid: data['uid'] as String,
        name: data['name'] as String,
        syncStatus: SyncStatus.synced,
      );
}
