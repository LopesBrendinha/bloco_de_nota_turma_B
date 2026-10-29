import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../utils/id_generator.dart';

/// Ordenações disponíveis na lista de notas.
enum NoteSort { updatedDesc, updatedAsc, createdDesc, createdAsc, titleAsc }

/// Acesso ao banco local SQLite.
///
/// Padrão Singleton: existe uma única instância ([instance]) e uma única
/// conexão aberta com o arquivo `notes.db` durante toda a execução do app.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const _dbVersion = 2;

  Future<Database> get database async {
    return _database ??= await _initDB('notes.db');
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, fileName),
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createNotesTable(DatabaseExecutor db, String name) {
    return db.execute('''
      CREATE TABLE $name(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT NOT NULL UNIQUE,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '${Note.defaultCategory}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createCategoriesTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT NOT NULL UNIQUE,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        UNIQUE(uid, name)
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    await _createNotesTable(db, 'notes');
    await _createCategoriesTable(db);
    await db.execute('CREATE INDEX idx_notes_uid ON notes(uid)');
  }

  /// Migração da versão 1 (id, uid, title, content, date) para a versão 2.
  /// As notas antigas são preservadas e marcadas como pendentes, para que
  /// sejam enviadas ao Firestore na primeira sincronização.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await _createNotesTable(txn, 'notes_v2');
        final now = DateTime.now().millisecondsSinceEpoch;
        final oldNotes = await txn.query('notes');
        for (final old in oldNotes) {
          await txn.insert('notes_v2', {
            'remote_id': generateId(),
            'uid': old['uid'],
            'title': old['title'],
            'content': old['content'],
            'category': Note.defaultCategory,
            'created_at': now,
            'updated_at': now,
            'sync_status': SyncStatus.pending.name,
          });
        }
        await txn.execute('DROP TABLE notes');
        await txn.execute('ALTER TABLE notes_v2 RENAME TO notes');
        await txn.execute('CREATE INDEX idx_notes_uid ON notes(uid)');
        await _createCategoriesTable(txn);
      });
    }
  }

  // ======================= NOTAS =======================

  static String _orderBy(NoteSort sort) {
    switch (sort) {
      case NoteSort.updatedDesc:
        return 'updated_at DESC';
      case NoteSort.updatedAsc:
        return 'updated_at ASC';
      case NoteSort.createdDesc:
        return 'created_at DESC';
      case NoteSort.createdAsc:
        return 'created_at ASC';
      case NoteSort.titleAsc:
        return 'title COLLATE NOCASE ASC';
    }
  }

  /// Notas ativas (fora da lixeira) do usuário, com pesquisa opcional por
  /// título/conteúdo e filtro opcional por categoria.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    NoteSort sort = NoteSort.updatedDesc,
  }) async {
    final db = await database;
    final where = StringBuffer(
      "uid = ? AND deleted_at IS NULL AND sync_status != 'pendingDelete'",
    );
    final args = <Object?>[uid];

    final q = query.trim();
    if (q.isNotEmpty) {
      // LIKE do SQLite já ignora maiúsculas/minúsculas para letras ASCII.
      // Os caracteres % e _ digitados pelo usuário são tratados como texto.
      final escaped = q
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      where.write(r" AND (title LIKE ? ESCAPE '\' OR content LIKE ? ESCAPE '\')");
      args.addAll(['%$escaped%', '%$escaped%']);
    }
    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }

    final result = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: _orderBy(sort),
    );
    return result.map(Note.fromMap).toList();
  }

  /// Notas que estão na lixeira.
  Future<List<Note>> getTrash(String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where:
          "uid = ? AND deleted_at IS NOT NULL AND sync_status != 'pendingDelete'",
      whereArgs: [uid],
      orderBy: 'deleted_at DESC',
    );
    return result.map(Note.fromMap).toList();
  }

  /// Todas as notas do usuário, incluindo lixeira e exclusões pendentes.
  /// Usado pela sincronização.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return result.map(Note.fromMap).toList();
  }

  Future<List<Note>> getUnsyncedNotes(String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: "uid = ? AND sync_status != 'synced'",
      whereArgs: [uid],
    );
    return result.map(Note.fromMap).toList();
  }

  Future<int> countUnsynced(String uid) async {
    final db = await database;
    final notes = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM notes WHERE uid = ? AND sync_status != 'synced'",
        [uid],
      ),
    );
    final categories = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM categories WHERE uid = ? AND sync_status != 'synced'",
        [uid],
      ),
    );
    return (notes ?? 0) + (categories ?? 0);
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    return db.insert('notes', map);
  }

  /// Atualiza a nota pelo [Note.remoteId], que é igual nos dois bancos.
  Future<int> updateNote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    return db.update(
      'notes',
      map,
      where: 'remote_id = ?',
      whereArgs: [note.remoteId],
    );
  }

  /// Insere ou substitui a nota vinda do Firestore.
  Future<void> upsertNote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    final updated = await db.update(
      'notes',
      map,
      where: 'remote_id = ?',
      whereArgs: [note.remoteId],
    );
    if (updated == 0) await db.insert('notes', map);
  }

  /// Marca como sincronizada somente se a nota não foi alterada de novo
  /// enquanto o envio estava em andamento.
  Future<void> markNoteSynced(String remoteId, DateTime updatedAt) async {
    final db = await database;
    await db.update(
      'notes',
      {'sync_status': SyncStatus.synced.name},
      where: 'remote_id = ? AND updated_at = ? AND sync_status = ?',
      whereArgs: [
        remoteId,
        updatedAt.millisecondsSinceEpoch,
        SyncStatus.pending.name,
      ],
    );
  }

  Future<int> deleteNote(String remoteId) async {
    final db = await database;
    return db.delete('notes', where: 'remote_id = ?', whereArgs: [remoteId]);
  }

  // ===================== CATEGORIAS =====================

  Future<List<NoteCategory>> getCategories(String uid) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return result.map(NoteCategory.fromMap).toList();
  }

  Future<List<NoteCategory>> getUnsyncedCategories(String uid) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: "uid = ? AND sync_status != 'synced'",
      whereArgs: [uid],
    );
    return result.map(NoteCategory.fromMap).toList();
  }

  Future<void> insertCategory(NoteCategory category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    await db.insert(
      'categories',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> upsertCategory(NoteCategory category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    final updated = await db.update(
      'categories',
      map,
      where: 'remote_id = ?',
      whereArgs: [category.remoteId],
    );
    if (updated == 0) {
      // Mesmo nome com outro ID (criada em dois aparelhos): mantém uma só.
      await db.insert(
        'categories',
        map,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> markCategorySynced(String remoteId) async {
    final db = await database;
    await db.update(
      'categories',
      {'sync_status': SyncStatus.synced.name},
      where: 'remote_id = ?',
      whereArgs: [remoteId],
    );
  }
}
