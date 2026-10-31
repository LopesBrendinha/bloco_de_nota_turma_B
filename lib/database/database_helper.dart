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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Geral',
        createdAt TEXT NOT NULL DEFAULT '',
        updatedAt TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  // Migração para bancos criados na versão 1 (sem os campos novos).
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'",
      );
      await db.execute(
        "ALTER TABLE notes ADD COLUMN createdAt TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE notes ADD COLUMN updatedAt TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await instance.database;

    // replace: se já existir uma nota com o mesmo id, ela é substituída.
    return await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: "id DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;

    return await db.update(
      'notes',
      note.toMap(),
      where: "id = ?",
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;

    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}