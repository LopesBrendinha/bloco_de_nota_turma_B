import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB("notes.db");
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
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Geral',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        deletedAt INTEGER,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories(
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (uid, name)
      )
    ''');
  }

  
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS categories');
    await _createDB(db, newVersion);
  }

 
  Future<void> upsertNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
  }) async {
    final db = await instance.database;

    final where = StringBuffer('uid = ? AND deletedAt IS NULL');
    final args = <Object?>[uid];

    if (category != null && category.isNotEmpty) {
      where.write(' AND category = ?');
      args.add(category);
    }

    if (query.trim().isNotEmpty) {
      where.write(' AND (title LIKE ? OR content LIKE ?)');
      final like = '%${query.trim()}%';
      args.addAll([like, like]);
    }

    final result = await db.query(
      'notes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );

    return result.map(Note.fromMap).toList();
  }

  /// Notas que estão na lixeira.
  Future<List<Note>> getTrashedNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND deletedAt IS NOT NULL',
      whereArgs: [uid],
      orderBy: 'deletedAt DESC',
    );

    return result.map(Note.fromMap).toList();
  }

  /// Todas as notas do usuário, inclusive as da lixeira.
  /// Usado na sincronização.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return result.map(Note.fromMap).toList();
  }


  Future<List<Note>> getUnsyncedNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    return result.map(Note.fromMap).toList();
  }

  Future<void> markAsSynced(String id) async {
    final db = await instance.database;

    await db.update('notes', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  
  Future<void> deleteNotePermanently(String id) async {
    final db = await instance.database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

 

  Future<List<String>> getCategories(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'categories',
      columns: ['name'],
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'name COLLATE NOCASE',
    );

    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> insertCategory(String uid, String name) async {
    final db = await instance.database;

    await db.insert(
      'categories',
      {'uid': uid, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}