import 'syncable.dart';

const Object _keep = Object();

/// Categoria de notas.
///
/// O nome não é `Category` porque o Flutter já tem uma classe com esse nome.
class NoteCategory implements Syncable {
  static const int maxNameLength = 40;

  /// Categorias que todo usuário tem. Ficam no código, com IDs fixos, para
  /// serem iguais em todos os aparelhos sem precisar de sincronização.
  static const List<NoteCategory> defaults = [
    NoteCategory(id: 'estudos', uid: '', name: 'Estudos', updatedAt: 0),
    NoteCategory(id: 'trabalho', uid: '', name: 'Trabalho', updatedAt: 0),
    NoteCategory(id: 'pessoal', uid: '', name: 'Pessoal', updatedAt: 0),
  ];

  @override
  final String id;
  final String uid;
  final String name;
  @override
  final int updatedAt;
  @override
  final int? syncedAt;

  const NoteCategory({
    required this.id,
    required this.uid,
    required this.name,
    required this.updatedAt,
    this.syncedAt,
  });

  bool get isDefault => defaults.any((category) => category.id == id);

  NoteCategory copyWith({Object? syncedAt = _keep}) {
    return NoteCategory(
      id: id,
      uid: uid,
      name: name,
      updatedAt: updatedAt,
      syncedAt: identical(syncedAt, _keep) ? this.syncedAt : syncedAt as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'updated_at': updatedAt,
      'synced_at': syncedAt,
    };
  }

  factory NoteCategory.fromMap(Map<String, dynamic> map) {
    return NoteCategory(
      id: map['id'] as String,
      uid: map['uid'] as String,
      name: map['name'] as String,
      updatedAt: map['updated_at'] as int,
      syncedAt: map['synced_at'] as int?,
    );
  }

  /// Documento `users/{uid}/categories/{id}` no Firestore.
  Map<String, dynamic> toRemoteMap() {
    return {'uid': uid, 'name': name, 'updatedAt': updatedAt};
  }

  factory NoteCategory.fromRemoteMap(String id, Map<String, dynamic> map) {
    return NoteCategory(
      id: id,
      uid: map['uid'] as String,
      name: map['name'] as String,
      updatedAt: (map['updatedAt'] as num).toInt(),
    );
  }
}
