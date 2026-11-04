import '../models/note.dart';
import '../models/note_category.dart';

enum RemoteErrorKind {
  /// Sem internet, servidor indisponível ou tempo esgotado.
  /// A operação pode dar certo em uma nova tentativa.
  offline,

  /// As regras de segurança recusaram a operação.
  permissionDenied,

  /// A sessão do usuário não é mais válida.
  unauthenticated,

  /// Limite de uso do plano do Firebase atingido.
  quotaExceeded,

  unknown,
}

class RemoteException implements Exception {
  final RemoteErrorKind kind;
  final String? detail;

  const RemoteException(this.kind, [this.detail]);

  @override
  String toString() => 'RemoteException($kind, $detail)';
}

/// O que a sincronização precisa de um armazenamento na nuvem.
///
/// O restante do aplicativo depende desta interface, e não do Firestore.
/// Isso permite testar a sincronização com uma nuvem falsa, simulando
/// falhas de conexão e permissões negadas.
///
/// Todos os métodos lançam [RemoteException] em caso de falha.
abstract interface class RemoteDataSource {
  Future<List<Note>> fetchNotes(String uid);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String uid, String id);

  Future<List<NoteCategory>> fetchCategories(String uid);
  Future<void> saveCategory(NoteCategory category);
  Future<void> deleteCategory(String uid, String id);
}
