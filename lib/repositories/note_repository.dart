import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../models/note_category.dart';
import '../services/sync_service.dart';

/// Situação da sincronização mostrada no topo da tela de notas.
enum SyncState { idle, syncing, synced, offline, error }

class SyncInfo {
  final SyncState state;
  final int pending;
  final String? message;
  final DateTime? lastSync;

  const SyncInfo({
    this.state = SyncState.idle,
    this.pending = 0,
    this.message,
    this.lastSync,
  });
}

/// Padrão Repository: as telas pedem e gravam notas só por aqui, sem saber
/// se os dados vêm do SQLite ou do Firestore.
///
/// Estratégia offline-first:
/// - Toda leitura é feita no SQLite (rápida e funciona sem internet).
/// - Toda gravação vai primeiro para o SQLite marcada como pendente e, logo
///   em seguida, uma sincronização é disparada em segundo plano.
///
/// [syncInfo] é um [ValueNotifier] (padrão Observer): a interface escuta as
/// mudanças e atualiza o ícone de sincronização sozinha.
class NoteRepository {
  NoteRepository._({DatabaseHelper? local, SyncService? sync})
    : _local = local ?? DatabaseHelper.instance,
      _sync = sync ?? SyncService();

  static final NoteRepository instance = NoteRepository._();

  final DatabaseHelper _local;
  final SyncService _sync;

  /// Notas na lixeira há mais tempo que isso são excluídas definitivamente.
  static const trashRetention = Duration(days: 30);

  final ValueNotifier<SyncInfo> syncInfo = ValueNotifier(const SyncInfo());

  // ---------------------- Leitura ----------------------

  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    NoteSort sort = NoteSort.updatedDesc,
  }) => _local.getNotes(uid, query: query, category: category, sort: sort);

  Future<List<Note>> getTrash(String uid) => _local.getTrash(uid);

  /// Categorias padrão + categorias criadas pelo usuário, sem repetição.
  Future<List<String>> getCategoryNames(String uid) async {
    final custom = await _local.getCategories(uid);
    final names = <String>[...NoteCategory.defaults];
    for (final c in custom) {
      if (!names.any((n) => n.toLowerCase() == c.name.toLowerCase())) {
        names.add(c.name);
      }
    }
    return names;
  }

  // ---------------------- Escrita ----------------------

  Future<Note> createNote({
    required String uid,
    required String title,
    required String content,
    required String category,
  }) async {
    final now = DateTime.now();
    final note = Note(
      uid: uid,
      title: title,
      content: content,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
    await _local.insertNote(note);
    _syncInBackground(uid);
    return note;
  }

  Future<void> updateNote(Note note) async {
    await _local.updateNote(
      note.copyWith(updatedAt: DateTime.now(), syncStatus: SyncStatus.pending),
    );
    _syncInBackground(note.uid);
  }

  /// Lixeira: a nota some da lista, mas pode ser recuperada.
  Future<void> moveToTrash(Note note) async {
    final now = DateTime.now();
    await _local.updateNote(
      note.copyWith(
        deletedAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );
    _syncInBackground(note.uid);
  }

  Future<void> restoreFromTrash(Note note) async {
    await _local.updateNote(
      note.copyWith(
        clearDeletedAt: true,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    _syncInBackground(note.uid);
  }

  /// Exclusão definitiva. Se a nota nunca chegou à nuvem, é apagada na hora;
  /// senão fica `pendingDelete` até o Firestore confirmar a exclusão.
  Future<void> deletePermanently(Note note) async {
    await _markForDeletion(note);
    _syncInBackground(note.uid);
  }

  Future<void> emptyTrash(String uid) async {
    for (final note in await _local.getTrash(uid)) {
      await _markForDeletion(note);
    }
    _syncInBackground(uid);
  }

  Future<void> _markForDeletion(Note note) async {
    await _local.updateNote(
      note.copyWith(
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pendingDelete,
      ),
    );
  }

  /// Exclui de vez as notas que estão na lixeira há mais de 30 dias.
  Future<void> purgeOldTrash(String uid) async {
    final limit = DateTime.now().subtract(trashRetention);
    for (final note in await _local.getTrash(uid)) {
      if (note.deletedAt!.isBefore(limit)) await _markForDeletion(note);
    }
  }

  /// Cria uma categoria personalizada. Retorna o nome final (se já existir
  /// uma com o mesmo nome, ignorando maiúsculas, reaproveita a existente).
  Future<String> addCategory(String uid, String name) async {
    final clean = name.trim();
    final existing = await getCategoryNames(uid);
    for (final n in existing) {
      if (n.toLowerCase() == clean.toLowerCase()) return n;
    }
    await _local.insertCategory(NoteCategory(uid: uid, name: clean));
    _syncInBackground(uid);
    return clean;
  }

  // ------------------- Sincronização -------------------

  Future<SyncResult> sync(String uid) async {
    syncInfo.value = SyncInfo(
      state: SyncState.syncing,
      pending: await _local.countUnsynced(uid),
      lastSync: syncInfo.value.lastSync,
    );

    final result = await _sync.sync(uid);
    final pending = await _local.countUnsynced(uid);

    if (result.success) {
      syncInfo.value = SyncInfo(
        state: SyncState.synced,
        pending: pending,
        lastSync: DateTime.now(),
      );
    } else {
      syncInfo.value = SyncInfo(
        state: result.isConnectionError ? SyncState.offline : SyncState.error,
        pending: pending,
        message: result.message,
        lastSync: syncInfo.value.lastSync,
      );
    }
    _changes.value++;
    return result;
  }

  /// Contador incrementado a cada sincronização concluída; a tela de notas
  /// escuta para recarregar a lista quando chegam dados da nuvem.
  final ValueNotifier<int> _changes = ValueNotifier(0);
  ValueListenable<int> get changes => _changes;

  void _syncInBackground(String uid) {
    sync(uid);
  }

  /// Limpa o estado exibido ao sair da conta.
  void reset() {
    syncInfo.value = const SyncInfo();
  }
}
