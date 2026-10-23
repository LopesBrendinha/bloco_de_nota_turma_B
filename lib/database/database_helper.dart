import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instace = DatabaseHelper._init();

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertNote(Note note) async {
    final db = await instace.database;

    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes(String uid) async{
    final db = await instace.database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: "id DESC"
    );

    return result.map((map)=>Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async{
    final db = await instace.database;

    return await db.update(
      'notes',
      note.toMap(),
      where: "id = ?",

      whereArgs: [note.id],
    );

  }

  Future<int> deleteNote(int id) async{
    final db = await instace.database;

    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

  }
}
