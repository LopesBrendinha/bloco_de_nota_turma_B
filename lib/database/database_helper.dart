import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper();

  static const _version = 2;

  // path/factory injetáveis para os testes (banco em memória via sqflite_common_ffi).
  final String? _path;
  final DatabaseFactory? _factory;
  Database? _database;

  DatabaseHelper({this._path, this._factory});

  Future<Database> get database async {
    return _database ??= await _initDB();
  }

  Future<Database> _initDB() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? join(await getDatabasesPath(), 'notes.db');

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: (db, _) => _createNotesTable(db),
        onUpgrade: _onUpgrade,
        singleInstance: path != inMemoryDatabasePath,
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createNotesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT NOT NULL UNIQUE,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Geral',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        trashed INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        purged INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // v1 -> v2: recria a tabela com os novos campos e preserva as notas antigas
  // (ficam com synced = 0 para subirem ao Firebase na próxima sincronização).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        final oldRows = await txn.query('notes');
        await txn.execute('DROP TABLE notes');
        await _createNotesTable(txn);

        for (final row in oldRows) {
          final date = _parseOldDate(row['date'] as String?);
          await txn.insert('notes', {
            'remote_id': const Uuid().v4(),
            'uid': row['uid'],
            'title': row['title'],
            'content': row['content'],
            'created_at': date.millisecondsSinceEpoch,
            'updated_at': date.millisecondsSinceEpoch,
          });
        }
      });
    }
  }

  // Formato antigo: "dd/MM/yyyy HH:mm".
  static DateTime _parseOldDate(String? value) {
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
    ).firstMatch(value ?? '');
    if (match == null) return DateTime.now();
    final p = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
    return DateTime(p[2], p[1], p[0], p[3], p[4]);
  }

  Future<Note> insertNote(Note note) async {
    final db = await database;
    final map = note.toMap()..remove('id');
    final id = await db.insert('notes', map);
    return note.copyWith(id: id);
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(
      'notes',
      note.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update('notes', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Notas visíveis do usuário, com pesquisa por título/conteúdo e filtro de categoria.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    bool trashed = false,
  }) async {
    final db = await database;
    final where = StringBuffer('uid = ? AND purged = 0 AND trashed = ?');
    final args = <Object>[uid, trashed ? 1 : 0];

    final q = query.trim();
    if (q.isNotEmpty) {
      where.write(' AND (title LIKE ? OR content LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
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
    return result.map(Note.fromMap).toList();
  }

  /// Todas as linhas do usuário (inclusive lixeira e pendentes de exclusão), usadas na sincronização.
  Future<List<Note>> getAllForSync(String uid) async {
    final db = await database;
    final result = await db.query('notes', where: 'uid = ?', whereArgs: [uid]);
    return result.map(Note.fromMap).toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM notes WHERE uid = ? AND purged = 0 ORDER BY category',
      [uid],
    );
    return result.map((r) => r['category'] as String).toList();
  }
}
