import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    _database ??= await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Geral',
        date TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_notes_sync_id ON notes(sync_id)');
  }

  // Migração da versão 1 (sem categoria/sincronização) para a 2.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.execute('ALTER TABLE notes ADD COLUMN sync_id TEXT');
      await db.execute(
        "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'",
      );
      await db.execute(
        "ALTER TABLE notes ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "UPDATE notes SET sync_id = uid || '-' || id, updated_at = '$now'",
      );
      await db.execute(
        'CREATE UNIQUE INDEX idx_notes_sync_id ON notes(sync_id)',
      );
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    return await db.update(
      'notes',
      map,
      where: 'sync_id = ? AND uid = ?',
      whereArgs: [note.syncId, note.uid],
    );
  }

  // Lista notas do usuário. Pesquisa por título OU conteúdo,
  // filtra por categoria e separa notas ativas das da lixeira.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    bool trashed = false,
  }) async {
    final db = await database;

    final where = StringBuffer('uid = ? AND deleted = ?');
    final args = <Object>[uid, trashed ? 1 : 0];

    final q = query.trim();
    if (q.isNotEmpty) {
      where.write(' AND (title LIKE ? OR content LIKE ?)');
      args.add('%$q%');
      args.add('%$q%');
    }

    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }

    final result = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM notes WHERE uid = ? AND deleted = 0 '
      'ORDER BY category',
      [uid],
    );
    return result.map((row) => row['category'] as String).toList();
  }

  Future<List<Note>> getUnsynced(String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<Note?> getBySyncId(String uid, String syncId) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'uid = ? AND sync_id = ?',
      whereArgs: [uid, syncId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Note.fromMap(result.first);
  }

  Future<void> markSynced(String syncId) async {
    final db = await database;
    await db.update(
      'notes',
      {'synced': 1},
      where: 'sync_id = ?',
      whereArgs: [syncId],
    );
  }

  // Grava uma nota que veio da nuvem (insere ou atualiza).
  Future<void> upsertFromRemote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    final updated = await db.update(
      'notes',
      map,
      where: 'sync_id = ? AND uid = ?',
      whereArgs: [note.syncId, note.uid],
    );
    if (updated == 0) {
      await db.insert('notes', map);
    }
  }

  Future<int> deleteNoteForever(String syncId) async {
    final db = await database;
    return await db.delete('notes', where: 'sync_id = ?', whereArgs: [syncId]);
  }
}
