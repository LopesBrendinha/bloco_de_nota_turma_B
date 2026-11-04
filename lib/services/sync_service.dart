import '../database/database_helper.dart';
import '../models/note.dart';
import '../models/note_category.dart';
import 'remote_data_source.dart';
import 'sync_planner.dart';

class SyncResult {
  /// Algo vindo da nuvem mudou no aparelho.
  final bool changedLocally;

  /// Motivo da falha. Null quando tudo terminou bem.
  final RemoteErrorKind? failure;

  const SyncResult({this.changedLocally = false, this.failure});
}

/// Mantém o SQLite e o Firestore iguais.
///
/// Uma rodada segue sempre esta ordem:
///
/// 1. Lê tudo da nuvem. Sem conexão, falha aqui e nada mais é tentado.
/// 2. Envia as exclusões pendentes.
/// 3. Compara os dois lados com [planSync] e aplica o resultado no SQLite.
/// 4. Envia para a nuvem o que ficou pendente.
///
/// Uma falha nunca perde dados: o que não foi concluído continua marcado
/// como pendente no SQLite e entra na próxima rodada.
class SyncService {
  final DatabaseHelper _database;
  final RemoteDataSource _remote;

  Future<SyncResult>? _running;
  String? _runningUid;
  bool _runAgain = false;

  SyncService(this._database, this._remote);

  /// Sincroniza as notas do usuário.
  ///
  /// Nunca há duas rodadas ao mesmo tempo. Um pedido feito durante uma
  /// rodada agenda outra para logo depois dela.
  Future<SyncResult> sync(String uid) {
    final running = _running;
    if (running == null) {
      _runningUid = uid;
      return _running = _runUntilSettled(uid);
    }
    if (_runningUid != uid) {
      // Outro usuário acabou de sair: espera a rodada dele terminar.
      return running.then((_) => sync(uid));
    }
    _runAgain = true;
    return running;
  }

  Future<SyncResult> _runUntilSettled(String uid) async {
    var changed = false;
    try {
      while (true) {
        _runAgain = false;
        final result = await _runOnce(uid);
        changed = changed || result.changedLocally;

        if (result.failure != null || !_runAgain) {
          return SyncResult(changedLocally: changed, failure: result.failure);
        }
      }
    } finally {
      _running = null;
    }
  }

  Future<SyncResult> _runOnce(String uid) async {
    var changed = false;
    try {
      final remoteNotes = await _remote.fetchNotes(uid);
      final remoteCategories = await _remote.fetchCategories(uid);

      final deleted = await _pushDeletions(uid);

      final categoriesPlan = planSync<NoteCategory>(
        local: await _database.getCategories(uid),
        remote: remoteCategories,
        pendingDeletions: deleted.categories,
      );
      changed = await _applyCategories(categoriesPlan) || changed;

      final notesPlan = planSync<Note>(
        local: await _database.getAllNotes(uid),
        remote: remoteNotes,
        pendingDeletions: deleted.notes,
      );
      changed = await _applyNotes(notesPlan) || changed;

      final failure = await _pushAll(categoriesPlan.push, notesPlan.push);
      return SyncResult(changedLocally: changed, failure: failure);
    } on RemoteException catch (error) {
      return SyncResult(changedLocally: changed, failure: error.kind);
    }
  }

  Future<({Set<String> notes, Set<String> categories})> _pushDeletions(
    String uid,
  ) async {
    final notes = <String>{};
    final categories = <String>{};

    for (final deletion in await _database.getPendingDeletions(uid)) {
      switch (deletion.collection) {
        case RemoteCollection.notes:
          notes.add(deletion.id);
          await _remote.deleteNote(uid, deletion.id);
        case RemoteCollection.categories:
          categories.add(deletion.id);
          await _remote.deleteCategory(uid, deletion.id);
      }
      await _database.removePendingDeletion(deletion);
    }

    return (notes: notes, categories: categories);
  }

  Future<bool> _applyNotes(SyncPlan<Note> plan) async {
    for (final update in plan.saveLocally) {
      await _database.saveRemoteNote(
        update.remote,
        expectedUpdatedAt: update.local?.updatedAt,
      );
    }
    for (final note in plan.deleteLocally) {
      await _database.removeNoteDeletedRemotely(note);
    }
    for (final note in plan.markSynced) {
      await _database.markNoteSynced(note);
    }
    return plan.saveLocally.isNotEmpty || plan.deleteLocally.isNotEmpty;
  }

  Future<bool> _applyCategories(SyncPlan<NoteCategory> plan) async {
    for (final update in plan.saveLocally) {
      await _database.saveRemoteCategory(
        update.remote,
        expectedUpdatedAt: update.local?.updatedAt,
      );
    }
    for (final category in plan.deleteLocally) {
      await _database.removeCategoryDeletedRemotely(category);
    }
    for (final category in plan.markSynced) {
      await _database.markCategorySynced(category);
    }
    return plan.saveLocally.isNotEmpty || plan.deleteLocally.isNotEmpty;
  }

  /// Envia os registros pendentes.
  ///
  /// Se um registro for recusado, os outros ainda são enviados. Se a conexão
  /// cair, a tentativa para, porque os próximos também falhariam.
  Future<RemoteErrorKind?> _pushAll(
    List<NoteCategory> categories,
    List<Note> notes,
  ) async {
    RemoteErrorKind? failure;

    Future<void> attempt(Future<void> Function() send) async {
      try {
        await send();
      } on RemoteException catch (error) {
        if (error.kind == RemoteErrorKind.offline) rethrow;
        failure ??= error.kind;
      }
    }

    for (final category in categories) {
      await attempt(() async {
        await _remote.saveCategory(category);
        await _database.markCategorySynced(category);
      });
    }
    for (final note in notes) {
      await attempt(() async {
        await _remote.saveNote(note);
        await _database.markNoteSynced(note);
      });
    }
    return failure;
  }
}
