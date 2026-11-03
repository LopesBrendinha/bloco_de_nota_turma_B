import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Critério de ordenação da lista de notas (sempre da mais recente
/// para a mais antiga).
enum NoteSort { updatedAt, createdAt }

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

  /// Da versão 1 para a 2 o ID passou de inteiro para UUID (texto),
  /// o que muda a chave primária. Como o SQLite não altera isso com
  /// ALTER TABLE, as tabelas são recriadas. Notas antigas de teste,
  /// só locais, são descartadas.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS categories');
    await _createDB(db, newVersion);
  }

  // ---------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------

  /// Insere a nota ou, se o ID já existir, substitui (upsert).
  /// Serve tanto para criar quanto para editar e para gravar
  /// notas baixadas do Firestore.
  Future<void> upsertNote(Note note) async {
    final db = await instance.database;

    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Notas ativas (fora da lixeira) do usuário, da mais recente para
  /// a mais antiga. Aceita busca por título/conteúdo, filtro de
  /// categoria e a escolha de ordenar por atualização ou por criação.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    NoteSort sort = NoteSort.updatedAt,
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
      orderBy: sort == NoteSort.createdAt
          ? 'createdAt DESC'
          : 'updatedAt DESC',
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

  /// Notas com alterações ainda não enviadas ao Firestore.
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

  /// Exclusão definitiva (só para notas que já estão na lixeira).
  Future<void> deleteNotePermanently(String id) async {
    final db = await instance.database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------

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

  /// Categorias que todo usuário já começa tendo. As que ele criar
  /// depois ficam na mesma tabela.
  static const List<String> defaultCategories = [
    'Geral',
    'Estudos',
    'Trabalho',
    'Pessoal',
  ];

  /// Garante as categorias padrão para o usuário. Pode ser chamado
  /// várias vezes: o que já existe é ignorado.
  Future<void> ensureDefaultCategories(String uid) async {
    for (final name in defaultCategories) {
      await insertCategory(uid, name);
    }
  }
}