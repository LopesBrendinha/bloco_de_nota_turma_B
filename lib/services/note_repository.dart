import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';

/// Padrão Repository: as telas só falam com esta classe e não sabem
/// se o dado veio do SQLite ou do Firestore.
///
/// Estratégia "local primeiro": toda alteração é gravada no SQLite e depois
/// enviada ao Firestore. Se o envio falhar, a nota fica com synced = false
/// e é reenviada na próxima sincronização.
///
/// Os métodos que escrevem retornam true quando a nuvem também foi atualizada.
class NoteRepository {
  final DatabaseHelper _local = DatabaseHelper.instance;
  final FirestoreService _remote = FirestoreService();

  String newId() => _remote.newId();

  // ---------- Leitura (sempre do SQLite) ----------
  Future<List<Note>> list(
    String uid, {
    bool archived = false,
    String query = '',
    String? category,
  }) {
    return _local.getNotes(
      uid,
      archived: archived,
      query: query,
      category: category,
    );
  }

  Future<List<String>> categories(String uid) => _local.getCategories(uid);

  // ---------- Escrita ----------
  Future<bool> save(Note note) async {
    final toSave = note.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      synced: false,
    );

    await _local.upsertNote(toSave);

    return _push(toSave);
  }

  Future<bool> setArchived(Note note, bool archived) {
    return save(note.copyWith(archived: archived));
  }

  Future<bool> delete(Note note) async {
    await _local.deleteNote(note.id);

    try {
      await _remote.deleteNote(note.uid, note.id);
      return true;
    } catch (_) {
      // Guarda a exclusão para repetir depois.
      await _local.addPendingDelete(note.id, note.uid);
      return false;
    }
  }

  Future<bool> _push(Note note) async {
    try {
      await _remote.saveNote(note);
      await _local.markSynced(note.id, note.updatedAt);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Sincronização completa ----------
  // 1) envia exclusões pendentes; 2) envia notas pendentes;
  // 3) baixa as notas da nuvem (vence a de updatedAt mais recente);
  // 4) remove localmente notas já sincronizadas que não existem mais na nuvem
  //    (foram excluídas em outro aparelho).
  Future<bool> sync(String uid) async {
    try {
      for (final id in await _local.getPendingDeletes(uid)) {
        await _remote.deleteNote(uid, id);
        await _local.removePendingDelete(id);
      }

      for (final note in await _local.getUnsynced(uid)) {
        await _remote.saveNote(note);
        await _local.markSynced(note.id, note.updatedAt);
      }

      final remoteNotes = await _remote.fetchNotes(uid);
      final remoteIds = <String>{};

      for (final remote in remoteNotes) {
        remoteIds.add(remote.id);

        final local = await _local.getNote(remote.id);

        if (local == null || remote.updatedAt > local.updatedAt) {
          await _local.upsertNote(remote);
        }
      }

      for (final id in await _local.getSyncedIds(uid)) {
        if (!remoteIds.contains(id)) {
          await _local.deleteNote(id);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
