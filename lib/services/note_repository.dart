import '../database/database_helper.dart';
import '../models/note.dart';
import 'firestore_service.dart';

// Repository: as telas falam só com esta classe, que decide
// quando usar o banco local (SQLite) e quando usar o Firestore.
class NoteRepository {
  final DatabaseHelper _local = DatabaseHelper.instance;
  final FirestoreService _remote = FirestoreService();

  Future<List<Note>> getNotes(String uid, {String search = ''}) {
    return _local.getNotes(uid, search: search);
  }

  // Retorna true se a nota também foi gravada no Firebase.
  Future<bool> saveNote(Note note, {required bool isNew}) async {
    if (isNew) {
      await _local.insertNote(note);
    } else {
      await _local.updateNote(note);
    }

    try {
      await _remote.saveNote(note);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Retorna true se a nota também foi removida do Firebase.
  Future<bool> deleteNote(Note note) async {
    await _local.deleteNote(note.id!);

    try {
      await _remote.deleteNote(note.uid, note.id!);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Sincroniza local e nuvem. Em caso de conflito, vence a nota
  // com updatedAt mais recente. Retorna false se o Firebase falhar.
  Future<bool> syncFromCloud(String uid) async {
    try {
      final remoteNotes = await _remote.fetchNotes(uid);
      final localNotes = await _local.getNotes(uid);

      final remoteById = {for (final n in remoteNotes) n.id!: n};
      final localById = {for (final n in localNotes) n.id!: n};

      // Envia para a nuvem o que só existe aqui ou está mais novo aqui.
      for (final local in localNotes) {
        final remote = remoteById[local.id];
        if (remote == null || local.updatedAt.compareTo(remote.updatedAt) > 0) {
          await _remote.saveNote(local);
        }
      }

      // Traz para o aparelho o que só existe na nuvem ou está mais novo lá.
      for (final remote in remoteNotes) {
        final local = localById[remote.id];
        if (local == null || remote.updatedAt.compareTo(local.updatedAt) > 0) {
          await _local.insertNote(remote);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}