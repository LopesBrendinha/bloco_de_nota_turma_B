import 'dart:async';

import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/repositories/notes_repository.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter/foundation.dart';

/// Estado da tela de notas (pesquisa, filtro, ordenação e lista). As páginas
/// observam este objeto com ListenableBuilder e chamam seus métodos; nenhuma
/// página fala direto com SQLite ou Firebase.
class NotesController extends ChangeNotifier {
  NotesController({required String uid}) {
    sync = SyncService(uid: uid, onLocalDataChanged: refresh);
    repository = NotesRepository(uid: uid, sync: sync);
  }

  late final SyncService sync;
  late final NotesRepository repository;

  List<Note> notes = [];
  List<NoteCategory> categories = [];
  String query = '';
  String? categoryId;
  NoteSort sort = const NoteSort();
  bool loading = true;

  Timer? _searchDebounce;
  bool _disposed = false;

  ValueListenable<SyncState> get syncState => sync.state;

  bool get isSearching => query.trim().isNotEmpty;

  Future<void> init() async {
    sort = await repository.loadSort();
    await repository.ensureDefaultCategories();
    await refresh();
    sync.start();
  }

  Future<void> refresh() async {
    final loadedCategories = await repository.getCategories();
    if (categoryId != null &&
        !loadedCategories.any((category) => category.id == categoryId)) {
      categoryId = null;
    }
    final loadedNotes = await repository.getNotes(
      query: query,
      categoryId: categoryId,
      sort: sort,
    );
    if (_disposed) return;
    categories = loadedCategories;
    notes = loadedNotes;
    loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> setCategory(String? id) async {
    categoryId = id;
    await refresh();
  }

  Future<void> setSort(NoteSort value) async {
    sort = value;
    await repository.saveSort(value);
    await refresh();
  }

  NoteCategory? categoryOf(String? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<Note> saveNote({
    Note? existing,
    required String title,
    required String content,
    String? categoryId,
  }) async {
    final note = await repository.saveNote(
      existing: existing,
      title: title,
      content: content,
      categoryId: categoryId,
    );
    await refresh();
    return note;
  }

  Future<void> deleteNote(Note note) async {
    await repository.deleteNote(note);
    await refresh();
  }

  Future<NoteCategory> saveCategory({
    NoteCategory? existing,
    required String name,
    required int color,
  }) async {
    final category = await repository.saveCategory(
      existing: existing,
      name: name,
      color: color,
    );
    await refresh();
    return category;
  }

  Future<void> deleteCategory(NoteCategory category) async {
    await repository.deleteCategory(category);
    await refresh();
  }

  Future<void> syncNow() => sync.sync();

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    sync.dispose();
    super.dispose();
  }
}
