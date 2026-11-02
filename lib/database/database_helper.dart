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

    // Versão 2: adiciona as colunas de sincronização com o Firestore.
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Executado quando o app é instalado pela primeira vez.
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // Executado quando o app já tinha o banco na versão 1.
  // Adiciona as colunas novas sem apagar as notas existentes.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN remote_id TEXT');
      await db.execute(
        'ALTER TABLE notes ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await instance.database;

    final map = note.toMap()..remove('id');

    return await db.insert('notes', map);
  }

  // Notas visíveis na tela (ignora as que estão com exclusão pendente).
  Future<List<Note>> getNotes(String uid) async{
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND deleted = 0',
      whereArgs: [uid],
      orderBy: "updated_at DESC, id DESC"
    );

    return result.map((map)=>Note.fromMap(map)).toList();
  }

  // Todas as notas do usuário, inclusive as com exclusão pendente.
  // Usado pela sincronização.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // Notas que ainda não foram enviadas para o Firestore.
  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // O filtro por uid garante que um usuário não altere
  // a nota de outro, mesmo no banco local.
  Future<int> updateNote(Note note) async{
    final db = await instance.database;

    final map = note.toMap()..remove('id');

    return await db.update(
      'notes',
      map,
      where: "id = ? AND uid = ?",

      whereArgs: [note.id, note.uid],
    );

  }

  Future<int> deleteNote(int id, String uid) async{
    final db = await instance.database;

    return await db.delete(
      'notes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );

  }
}
