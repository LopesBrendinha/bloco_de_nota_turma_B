import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_category.dart';
import 'package:blocodenotasturmab/services/remote_data_source.dart';

/// Nuvem em memória, com falhas programáveis.
///
/// Dois [SyncService] ligados à mesma instância simulam dois aparelhos.
class FakeRemoteDataSource implements RemoteDataSource {
  final Map<String, Note> notes = {};
  final Map<String, NoteCategory> categories = {};

  /// Quando preenchido, toda operação falha com este erro.
  RemoteErrorKind? failure;

  /// IDs de notas que as "regras de segurança" recusam.
  final Set<String> rejectedNoteIds = {};

  /// Número de envios de notas antes de a conexão cair.
  int? savesBeforeOffline;

  /// Executado no meio de um envio, para simular ações do usuário.
  Future<void> Function(Note note)? onSaveNote;

  int fetchCount = 0;
  int saveAttempts = 0;

  void _check() {
    if (failure != null) throw RemoteException(failure!);
  }

  @override
  Future<List<Note>> fetchNotes(String uid) async {
    _check();
    fetchCount++;
    return notes.values.where((note) => note.uid == uid).toList();
  }

  @override
  Future<void> saveNote(Note note) async {
    saveAttempts++;
    _check();

    final remaining = savesBeforeOffline;
    if (remaining != null) {
      if (remaining == 0) {
        throw const RemoteException(RemoteErrorKind.offline);
      }
      savesBeforeOffline = remaining - 1;
    }

    if (rejectedNoteIds.contains(note.id)) {
      throw const RemoteException(RemoteErrorKind.permissionDenied);
    }

    // Como no Firestore, só os campos de toRemoteMap chegam à nuvem.
    notes[note.id] = Note.fromRemoteMap(note.id, note.toRemoteMap());
    await onSaveNote?.call(note);
  }

  @override
  Future<void> deleteNote(String uid, String id) async {
    _check();
    notes.remove(id);
  }

  @override
  Future<List<NoteCategory>> fetchCategories(String uid) async {
    _check();
    return categories.values.where((item) => item.uid == uid).toList();
  }

  @override
  Future<void> saveCategory(NoteCategory category) async {
    _check();
    categories[category.id] = NoteCategory.fromRemoteMap(
      category.id,
      category.toRemoteMap(),
    );
  }

  @override
  Future<void> deleteCategory(String uid, String id) async {
    _check();
    categories.remove(id);
  }
}
