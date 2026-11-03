import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_engine.dart';

class NoteSyncAdapter implements SyncAdapter<Note> {
  NoteSyncAdapter(this.uid, this.local, this.remote);

  final String uid;
  final DatabaseHelper local;
  final FirestoreService remote;

  @override
  Future<List<Note>> localAll() => local.notesForSync(uid);

  @override
  Future<void> applyRemote(Note item) => local.applyRemoteNote(item);

  @override
  Future<void> markSynced(String id, int updatedAt) =>
      local.markNoteSynced(id, updatedAt);

  @override
  Future<void> localRemove(String id, SyncStatus onlyIf) =>
      local.removeNote(id, onlyIf);

  @override
  Future<List<Note>> remoteAll() => remote.fetchNotes(uid);

  @override
  Future<void> remoteUpsert(Note item) => remote.upsertNote(item);

  @override
  Future<void> remoteDelete(String id) => remote.deleteNote(uid, id);
}

class CategorySyncAdapter implements SyncAdapter<NoteCategory> {
  CategorySyncAdapter(this.uid, this.local, this.remote);

  final String uid;
  final DatabaseHelper local;
  final FirestoreService remote;

  @override
  Future<List<NoteCategory>> localAll() => local.categoriesForSync(uid);

  @override
  Future<void> applyRemote(NoteCategory item) =>
      local.applyRemoteCategory(item);

  @override
  Future<void> markSynced(String id, int updatedAt) =>
      local.markCategorySynced(id, updatedAt);

  @override
  Future<void> localRemove(String id, SyncStatus onlyIf) =>
      local.removeCategory(id, onlyIf);

  @override
  Future<List<NoteCategory>> remoteAll() => remote.fetchCategories(uid);

  @override
  Future<void> remoteUpsert(NoteCategory item) => remote.upsertCategory(item);

  @override
  Future<void> remoteDelete(String id) => remote.deleteCategory(uid, id);
}
