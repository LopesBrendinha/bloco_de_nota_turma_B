import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/utils/text_normalizer.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acesso ao banco local (SQLite). É a fonte de verdade da interface: a tela
/// sempre lê daqui, e o Firestore é alcançado apenas pelo SyncService.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const _notes = 'notes';
  static const _categories = 'categories';
  static const _settings = 'settings';

  Future<Database> get database async {
    return _database ??= await _initDB('grafite.db');
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_notes(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        search_text TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_uid_updated ON $_notes(uid, updated_at)',
    );
    await db.execute(
      'CREATE INDEX idx_notes_uid_created ON $_notes(uid, created_at)',
    );
    await db.execute('''
      CREATE TABLE $_categories(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------- notas

  /// Notas visíveis do usuário, já filtradas e ordenadas pelo SQLite.
  /// A pesquisa usa a coluna `search_text` (título + conteúdo sem acentos).
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? categoryId,
    NoteSort sort = const NoteSort(),
  }) async {
    final db = await database;
    final where = StringBuffer('uid = ? AND sync_status != ?');
    final args = <Object?>[uid, SyncStatus.pendingDelete.value];

    if (categoryId != null) {
      where.write(' AND category_id = ?');
      args.add(categoryId);
    }

    final term = normalizeForSearch(query.trim());
    if (term.isNotEmpty) {
      where.write(r" AND search_text LIKE ? ESCAPE '\'");
      args.add('%${_escapeLike(term)}%');
    }

    final result = await db.query(
      _notes,
      where: where.toString(),
      whereArgs: args,
      orderBy: sort.orderBy,
    );
    return result.map(Note.fromMap).toList();
  }

  Future<void> saveNote(Note note) async {
    final db = await database;
    await db.insert(
      _notes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Exclusão lógica: a linha fica marcada até o Firestore confirmar.
  Future<void> markNoteDeleted(String id, int updatedAt) async {
    final db = await database;
    await db.update(
      _notes,
      {'sync_status': SyncStatus.pendingDelete.value, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove a categoria das notas que a usavam (ao excluir a categoria).
  Future<void> clearCategoryFromNotes(
    String uid,
    String categoryId,
    int updatedAt,
  ) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $_notes
      SET category_id = NULL,
          updated_at = ?,
          sync_status = CASE WHEN sync_status = ? THEN sync_status ELSE ? END
      WHERE uid = ? AND category_id = ?
      ''',
      [
        updatedAt,
        SyncStatus.pendingDelete.value,
        SyncStatus.pendingUpsert.value,
        uid,
        categoryId,
      ],
    );
  }

  Future<List<Note>> notesForSync(String uid) async {
    final rows = await _rowsForSync(_notes, uid);
    return rows.map(Note.fromMap).toList();
  }

  Future<void> applyRemoteNote(Note note) => _applyRemote(_notes, note.toMap());

  Future<void> markNoteSynced(String id, int updatedAt) =>
      _markSynced(_notes, id, updatedAt);

  Future<void> removeNote(String id, SyncStatus onlyIf) =>
      _remove(_notes, id, onlyIf);

  // ----------------------------------------------------------- categorias

  Future<List<NoteCategory>> getCategories(String uid) async {
    final db = await database;
    final result = await db.query(
      _categories,
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.pendingDelete.value],
      orderBy: 'created_at ASC, name ASC',
    );
    return result.map(NoteCategory.fromMap).toList();
  }

  Future<void> saveCategory(NoteCategory category) async {
    final db = await database;
    await db.insert(
      _categories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markCategoryDeleted(String id, int updatedAt) async {
    final db = await database;
    await db.update(
      _categories,
      {'sync_status': SyncStatus.pendingDelete.value, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<NoteCategory>> categoriesForSync(String uid) async {
    final rows = await _rowsForSync(_categories, uid);
    return rows.map(NoteCategory.fromMap).toList();
  }

  Future<void> applyRemoteCategory(NoteCategory category) =>
      _applyRemote(_categories, category.toMap());

  Future<void> markCategorySynced(String id, int updatedAt) =>
      _markSynced(_categories, id, updatedAt);

  Future<void> removeCategory(String id, SyncStatus onlyIf) =>
      _remove(_categories, id, onlyIf);

  // ------------------------------------------------------- sincronização

  /// Quantas alterações locais ainda não chegaram ao Firestore.
  Future<int> pendingCount(String uid) async {
    final db = await database;
    var total = 0;
    for (final table in [_notes, _categories]) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM $table WHERE uid = ? AND sync_status != ?',
        [uid, SyncStatus.synced.value],
      );
      total += Sqflite.firstIntValue(result) ?? 0;
    }
    return total;
  }

  Future<List<Map<String, Object?>>> _rowsForSync(
    String table,
    String uid,
  ) async {
    final db = await database;
    return db.query(table, where: 'uid = ?', whereArgs: [uid]);
  }

  /// Grava a versão vinda do Firestore, exceto se o aparelho tiver uma
  /// alteração pendente mais nova (feita enquanto a sincronização rodava).
  Future<void> _applyRemote(String table, Map<String, Object?> row) async {
    final db = await database;
    await db.transaction((txn) async {
      final current = await txn.query(
        table,
        columns: ['updated_at', 'sync_status'],
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      if (current.isNotEmpty) {
        final localStatus = SyncStatus.parse(
          current.first['sync_status'] as String?,
        );
        final localUpdatedAt = current.first['updated_at'] as int;
        if (localStatus != SyncStatus.synced &&
            localUpdatedAt > (row['updated_at'] as int)) {
          return;
        }
      }
      await txn.insert(table, {
        ...row,
        'sync_status': SyncStatus.synced.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Só marca como sincronizado se a linha não mudou desde o envio.
  Future<void> _markSynced(String table, String id, int updatedAt) async {
    final db = await database;
    await db.update(
      table,
      {'sync_status': SyncStatus.synced.value},
      where: 'id = ? AND updated_at = ? AND sync_status = ?',
      whereArgs: [id, updatedAt, SyncStatus.pendingUpsert.value],
    );
  }

  Future<void> _remove(String table, String id, SyncStatus onlyIf) async {
    final db = await database;
    await db.delete(
      table,
      where: 'id = ? AND sync_status = ?',
      whereArgs: [id, onlyIf.value],
    );
  }

  // --------------------------------------------------------- preferências

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      _settings,
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isEmpty ? null : result.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(_settings, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String _escapeLike(String term) {
    return term
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
