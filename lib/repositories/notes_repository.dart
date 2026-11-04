import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../models/note_category.dart';
import '../models/sync_status.dart';
import '../services/sync_service.dart';
import '../utils/date_utils.dart';
import '../utils/id_generator.dart';
import '../utils/text_utils.dart';

/// Já existe uma categoria com o nome informado.
class CategoryExistsException implements Exception {
  const CategoryExistsException();
}

/// Única porta de entrada das telas para os dados (padrão Repository).
///
/// A estratégia é *offline-first*: toda leitura e escrita acontece primeiro
/// no SQLite, que responde na hora e funciona sem internet. A sincronização
/// com o Firestore roda depois, em segundo plano.
///
/// As telas se inscrevem neste [ChangeNotifier] (padrão Observer) e recarregam
/// os dados sempre que algo muda.
class NotesRepository extends ChangeNotifier {
  final DatabaseHelper _database;
  final SyncService _sync;

  /// Espera após uma alteração, para juntar edições próximas em um só envio.
  final Duration syncDelay;

  /// Intervalo entre tentativas enquanto houver algo pendente.
  final Duration retryInterval;

  String? _uid;
  SyncStatus _status = const SyncStatus();
  Timer? _syncTimer;

  NotesRepository(
    this._database,
    this._sync, {
    this.syncDelay = const Duration(seconds: 1),
    this.retryInterval = const Duration(seconds: 30),
  });

  SyncStatus get status => _status;

  String get _currentUid {
    final uid = _uid;
    if (uid == null) throw StateError('Nenhum usuário autenticado.');
    return uid;
  }

  /// Começa a trabalhar com as notas do usuário que entrou no aplicativo.
  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _status = const SyncStatus();
    unawaited(syncNow());
  }

  /// Encerra a sessão. As alterações pendentes ficam guardadas no SQLite e
  /// são enviadas quando o mesmo usuário entrar de novo.
  void stop() {
    _syncTimer?.cancel();
    _uid = null;
    _status = const SyncStatus();
  }

  /// Executa uma rodada de sincronização e atualiza o status.
  Future<void> syncNow() async {
    final uid = _uid;
    if (uid == null) return;

    _syncTimer?.cancel();
    _setStatus(
      SyncStatus(
        state: SyncState.syncing,
        pendingChanges: _status.pendingChanges,
        lastSyncAt: _status.lastSyncAt,
      ),
    );

    final result = await _sync.sync(uid);
    if (_uid != uid) return;

    final pending = await _database.countPendingChanges(uid);
    if (_uid != uid) return;

    final failed = result.failure != null;
    _setStatus(
      SyncStatus(
        state: failed ? SyncState.failed : SyncState.synced,
        pendingChanges: pending,
        lastSyncAt: failed
            ? _status.lastSyncAt
            : DateTime.now().millisecondsSinceEpoch,
        failure: result.failure,
      ),
    );

    if (pending > 0 || _status.isOffline) _scheduleSync(retryInterval);
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    notifyListeners();
  }

  void _scheduleSync(Duration delay) {
    _syncTimer?.cancel();
    _syncTimer = Timer(delay, () => unawaited(syncNow()));
  }

  /// Avisa as telas sobre uma alteração local e agenda o envio.
  Future<void> _afterLocalChange() async {
    final uid = _uid;
    if (uid == null) return;

    _status = SyncStatus(
      state: _status.state,
      pendingChanges: await _database.countPendingChanges(uid),
      lastSyncAt: _status.lastSyncAt,
      failure: _status.failure,
    );
    notifyListeners();
    _scheduleSync(syncDelay);
  }

  // ---------------------------------------------------------------- Notas

  Future<List<Note>> getNotes({String query = '', String? categoryId}) {
    return _database.getNotes(
      _currentUid,
      query: query,
      categoryId: categoryId,
    );
  }

  Future<List<Note>> getTrashedNotes() {
    return _database.getTrashedNotes(_currentUid);
  }

  /// Cria uma nota nova ou atualiza a nota com o [id] informado.
  Future<void> saveNote({
    String? id,
    required String title,
    required String content,
    String? categoryId,
  }) async {
    final uid = _currentUid;
    final current = id == null ? null : await _database.getNote(id);

    if (current != null) {
      await _database.updateNote(
        current.copyWith(
          title: title,
          content: content,
          categoryId: categoryId,
          updatedAt: nextTimestamp(current.updatedAt),
        ),
      );
    } else {
      // Sem registro atual, a nota é nova ou foi apagada em outro aparelho
      // enquanto estava aberta. Nos dois casos, o texto digitado é mantido.
      final now = nextTimestamp(null);
      await _database.insertNote(
        Note(
          id: id ?? generateId(),
          uid: uid,
          title: title,
          content: content,
          categoryId: categoryId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await _afterLocalChange();
  }

  /// Envia a nota para a lixeira, de onde ela ainda pode ser recuperada.
  Future<void> moveToTrash(String id) async {
    final note = await _database.getNote(id);
    if (note == null) return;

    final now = nextTimestamp(note.updatedAt);
    await _database.updateNote(note.copyWith(trashedAt: now, updatedAt: now));
    await _afterLocalChange();
  }

  /// Tira a nota da lixeira.
  Future<void> restoreNote(String id) async {
    final note = await _database.getNote(id);
    if (note == null) return;

    await _database.updateNote(
      note.copyWith(trashedAt: null, updatedAt: nextTimestamp(note.updatedAt)),
    );
    await _afterLocalChange();
  }

  /// Apaga a nota definitivamente, no aparelho e na nuvem.
  Future<void> deleteNotePermanently(String id) async {
    await _database.deleteNote(_currentUid, id);
    await _afterLocalChange();
  }

  /// Apaga definitivamente todas as notas da lixeira.
  Future<void> emptyTrash() async {
    final uid = _currentUid;
    for (final note in await _database.getTrashedNotes(uid)) {
      await _database.deleteNote(uid, note.id);
    }
    await _afterLocalChange();
  }

  // ----------------------------------------------------------- Categorias

  /// Categorias padrão seguidas das criadas pelo usuário.
  Future<List<NoteCategory>> getCategories() async {
    return [
      ...NoteCategory.defaults,
      ...await _database.getCategories(_currentUid),
    ];
  }

  /// Cria uma categoria, sem aceitar nomes repetidos.
  Future<NoteCategory> createCategory(String name) async {
    final uid = _currentUid;
    final cleanName = name.trim();
    final key = normalizeForSearch(cleanName);

    final existing = await getCategories();
    if (existing.any((item) => normalizeForSearch(item.name) == key)) {
      throw const CategoryExistsException();
    }

    final category = NoteCategory(
      id: generateId(),
      uid: uid,
      name: cleanName,
      updatedAt: nextTimestamp(null),
    );
    await _database.insertCategory(category);
    await _afterLocalChange();
    return category;
  }

  /// Apaga uma categoria criada pelo usuário. As notas dela são mantidas.
  Future<void> deleteCategory(String id) async {
    await _database.deleteCategory(_currentUid, id);
    await _afterLocalChange();
  }
}
