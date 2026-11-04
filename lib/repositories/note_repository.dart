import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/note_remote_service.dart';
import 'package:flutter/foundation.dart';

/// Ponto único de acesso às notas (padrão Repository).
///
/// Estratégia offline-first: toda operação grava primeiro no SQLite e
/// depois tenta enviar ao Firestore. Se a nuvem falhar, a nota fica com
/// `synced = false` e é reenviada em [sync].
class NoteRepository {
  final DatabaseHelper _local;
  final NoteRemoteDataSource _remote;
  final DateTime Function() _clock;

  NoteRepository({
    DatabaseHelper? local,
    NoteRemoteDataSource? remote,
    DateTime Function()? clock,
  })  : _local = local ?? DatabaseHelper.instance,
        _remote = remote ?? FirestoreNoteRemote(),
        _clock = clock ?? DateTime.now;

  Future<List<Note>> getNotes(String uid, {String query = '', String? category}) =>
      _local.getNotes(uid, query: query, category: category);

  Future<List<Note>> getTrash(String uid) => _local.getNotes(uid, trashed: true);

  /// Categorias padrão + as criadas pelo usuário (vindas das notas).
  Future<List<String>> getCategories(String uid) async {
    final used = await _local.getCategories(uid);
    return {...Note.defaultCategories, ...used}.toList();
  }

  /// Cria ou atualiza. Retorna true se também foi salva na nuvem.
  Future<bool> save(Note note) async {
    final pending = note.copyWith(updatedAt: _clock(), synced: false);
    final saved = pending.id == null
        ? await _local.insertNote(pending)
        : await _local.updateNote(pending).then((_) => pending);
    return _push(saved);
  }

  Future<bool> moveToTrash(Note note) => save(note.copyWith(trashed: true));

  Future<bool> restore(Note note) => save(note.copyWith(trashed: false));

  /// Exclusão definitiva. Sem conexão, a linha fica marcada como `purged`
  /// (oculta) até que a remoção na nuvem seja confirmada.
  Future<bool> deleteForever(Note note) async {
    await _local.updateNote(note.copyWith(purged: true, synced: false));
    try {
      await _remote.delete(note.uid, note.remoteId);
      await _local.deleteNote(note.id!);
      return true;
    } catch (e) {
      debugPrint('Falha ao excluir na nuvem: $e');
      return false;
    }
  }

  Future<bool> emptyTrash(String uid) async {
    var ok = true;
    for (final note in await getTrash(uid)) {
      ok = await deleteForever(note) && ok;
    }
    return ok;
  }

  /// Sincronização bidirecional. Retorna false se não foi possível acessar a nuvem
  /// (os dados locais continuam intactos).
  ///
  /// 1. Baixa as notas da nuvem e mescla por `remoteId` (vence o `updatedAt` mais recente).
  /// 2. Notas locais já sincronizadas que sumiram da nuvem foram excluídas em
  ///    outra instalação, então são removidas aqui também.
  /// 3. Envia as pendências locais (criações, edições e exclusões).
  Future<bool> sync(String uid) async {
    try {
      final remoteNotes = await _remote.fetchAll(uid);
      final localByRemoteId = {
        for (final n in await _local.getAllForSync(uid)) n.remoteId: n,
      };

      for (final remote in remoteNotes) {
        final local = localByRemoteId.remove(remote.remoteId);
        if (local == null) {
          await _local.insertNote(remote.copyWith(synced: true));
        } else if (!local.purged &&
            remote.updatedAt.isAfter(local.updatedAt)) {
          await _local.updateNote(remote.copyWith(id: local.id, synced: true));
        }
      }

      for (final orphan in localByRemoteId.values) {
        if (orphan.synced) await _local.deleteNote(orphan.id!);
      }

      for (final note in await _local.getAllForSync(uid)) {
        if (note.synced) continue;
        if (note.purged) {
          await _remote.delete(uid, note.remoteId);
          await _local.deleteNote(note.id!);
        } else {
          await _remote.upsert(note);
          await _local.markSynced(note.id!);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Falha na sincronização: $e');
      return false;
    }
  }

  Future<bool> _push(Note note) async {
    try {
      await _remote.upsert(note);
      await _local.markSynced(note.id!);
      return true;
    } catch (e) {
      debugPrint('Nota salva só localmente: $e');
      return false;
    }
  }
}
