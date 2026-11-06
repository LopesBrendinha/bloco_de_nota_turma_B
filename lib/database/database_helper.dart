import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acesso ao banco local (SQLite). Padrão Singleton: existe uma única instância.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // A versão 1 usava id numérico. Como o Firestore precisa de id
        // em texto, recriamos as tabelas (os dados voltam via sincronização).
        await db.execute('DROP TABLE IF EXISTS notes');
        await db.execute('DROP TABLE IF EXISTS pending_deletes');
        await _createDB(db, newVersion);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Exclusões que ainda não chegaram ao Firestore (ex.: estava sem internet).
    await db.execute('''
      CREATE TABLE pending_deletes(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL
      )
    ''');
  }

  // INSERT ou UPDATE (se o id já existir, substitui).
  Future<void> upsertNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getNote(String id) async {
    final db = await instance.database;

    final result = await db.query('notes', where: 'id = ?', whereArgs: [id]);

    return result.isEmpty ? null : Note.fromMap(result.first);
  }

  /// Lista as notas do usuário, com filtros opcionais de arquivadas,
  /// categoria e pesquisa (título OU conteúdo).
  Future<List<Note>> getNotes(
    String uid, {
    bool archived = false,
    String query = '',
    String? category,
  }) async {
    final db = await instance.database;

    final where = StringBuffer('uid = ? AND archived = ?');
    final args = <Object?>[uid, archived ? 1 : 0];

    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }

    final text = query.trim();
    if (text.isNotEmpty) {
      where.write(' AND (title LIKE ? OR content LIKE ?)');
      args.add('%$text%');
      args.add('%$text%');
    }

    final result = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;

    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM notes WHERE uid = ? ORDER BY category',
      [uid],
    );

    return result.map((row) => row['category'] as String).toList();
  }

  Future<List<Note>> getUnsynced(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<String>> getSyncedIds(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      columns: ['id'],
      where: 'uid = ? AND synced = 1',
      whereArgs: [uid],
    );

    return result.map((row) => row['id'] as String).toList();
  }

  // Só marca como sincronizada se a nota não mudou desde o envio.
  Future<void> markSynced(String id, int updatedAt) async {
    final db = await instance.database;

    await db.update(
      'notes',
      {'synced': 1},
      where: 'id = ? AND updatedAt = ?',
      whereArgs: [id, updatedAt],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await instance.database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addPendingDelete(String id, String uid) async {
    final db = await instance.database;

    await db.insert('pending_deletes', {
      'id': id,
      'uid': uid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<String>> getPendingDeletes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'pending_deletes',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return result.map((row) => row['id'] as String).toList();
  }

  Future<void> removePendingDelete(String id) async {
    final db = await instance.database;

    await db.delete('pending_deletes', where: 'id = ?', whereArgs: [id]);
  }
}
