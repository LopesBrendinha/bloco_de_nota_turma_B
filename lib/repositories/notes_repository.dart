import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Ponto único de acesso aos dados para a interface (Repository).
///
/// Toda escrita segue o mesmo caminho: grava no SQLite como pendente e pede
/// uma sincronização. Assim o app funciona offline e a tela nunca espera a
/// rede para mostrar o resultado.
class NotesRepository {
  NotesRepository({
    required this.uid,
    required this.sync,
    DatabaseHelper? database,
  }) : _db = database ?? DatabaseHelper.instance;

  final String uid;
  final SyncService sync;
  final DatabaseHelper _db;
  static const _uuid = Uuid();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------- notas

  Future<List<Note>> getNotes({
    String query = '',
    String? categoryId,
    NoteSort sort = const NoteSort(),
  }) {
    return _db.getNotes(uid, query: query, categoryId: categoryId, sort: sort);
  }

  Future<Note> saveNote({
    Note? existing,
    required String title,
    required String content,
    String? categoryId,
  }) async {
    final now = _now;
    final note = existing == null
        ? Note(
            id: _uuid.v4(),
            uid: uid,
            title: title,
            content: content,
            categoryId: categoryId,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            title: title,
            content: content,
            categoryId: categoryId,
            clearCategory: categoryId == null,
            updatedAt: now,
            syncStatus: SyncStatus.pendingUpsert,
          );
    await _db.saveNote(note);
    sync.scheduleSync();
    return note;
  }

  Future<void> deleteNote(Note note) async {
    await _db.markNoteDeleted(note.id, _now);
    sync.scheduleSync();
  }

  // ----------------------------------------------------------- categorias

  Future<List<NoteCategory>> getCategories() => _db.getCategories(uid);

  Future<NoteCategory> saveCategory({
    NoteCategory? existing,
    required String name,
    required int color,
  }) async {
    final now = _now;
    final category = existing == null
        ? NoteCategory(
            id: _uuid.v4(),
            uid: uid,
            name: name,
            color: color,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: name,
            color: color,
            updatedAt: now,
            syncStatus: SyncStatus.pendingUpsert,
          );
    await _db.saveCategory(category);
    sync.scheduleSync();
    return category;
  }

  /// As notas da categoria não são apagadas: ficam "sem categoria".
  Future<void> deleteCategory(NoteCategory category) async {
    final now = _now;
    await _db.clearCategoryFromNotes(uid, category.id, now);
    await _db.markCategoryDeleted(category.id, now);
    sync.scheduleSync();
  }

  /// Cria Estudos, Trabalho e Pessoal na primeira vez que o usuário usa este
  /// aparelho. Os ids são fixos por usuário e o `updatedAt` é 0, então se a
  /// nuvem já tiver essas categorias (renomeadas, por exemplo) a versão
  /// remota sempre vence e nada é duplicado.
  Future<void> ensureDefaultCategories() async {
    final key = 'defaults_seeded_$uid';
    if (await _db.getSetting(key) != null) return;
    if ((await _db.categoriesForSync(uid)).isEmpty) {
      const defaults = [
        ('estudos', 'Estudos', 3),
        ('trabalho', 'Trabalho', 4),
        ('pessoal', 'Pessoal', 1),
      ];
      for (final (slug, name, color) in defaults) {
        await _db.saveCategory(
          NoteCategory(
            id: '${uid}_$slug',
            uid: uid,
            name: name,
            color: color,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }
    }
    await _db.setSetting(key, '1');
  }

  // --------------------------------------------------------- preferências

  Future<NoteSort> loadSort() async =>
      NoteSort.decode(await _db.getSetting('sort_$uid'));

  Future<void> saveSort(NoteSort sort) =>
      _db.setSetting('sort_$uid', sort.encode());
}
