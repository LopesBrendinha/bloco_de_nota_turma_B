import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../models/note_sort.dart';
import '../models/sync_status.dart';
import '../utils/text_normalizer.dart';

/// Acesso ao banco de dados local (SQLite via `sqflite`).
///
/// Implementa o padrão **Singleton**: existe uma única instância e uma única
/// conexão aberta com o arquivo `notes.db` durante todo o ciclo de vida do
/// aplicativo. Abrir o banco mais de uma vez causaria travas de escrita.
///
/// Esta classe conhece apenas SQL. Ela não sabe que o Firestore existe —
/// quem coordena os dois armazenamentos é o `NoteRepository`.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper._internal();

  static Database? _database;

  static const _databaseName = 'notes.db';

  /// Versão 1: esquema original (id, uid, title, content, date).
  /// Versão 2: UUID compartilhado, categorias, lixeira e fila de sincronização.
  static const _databaseVersion = 2;

  static const _uuid = Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _open();
    return _database!;
  }

  /// Fecha a conexão e apaga o arquivo do banco.
  ///
  /// Existe apenas para os testes poderem simular "outra instalação" do
  /// aplicativo, com o armazenamento local vazio e a nuvem intacta.
  @visibleForTesting
  Future<void> resetForTests() async {
    await _database?.close();
    _database = null;

    final path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Necessário para o ON DELETE SET NULL entre notas e categorias.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCategoriesTable(db);
    await _createNotesTable(db);
    await _createIndexes(db);
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories(
        local_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        id          TEXT    NOT NULL UNIQUE,
        uid         TEXT    NOT NULL,
        name        TEXT    NOT NULL,
        color       INTEGER NOT NULL,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        sync_status INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notes(
        local_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        id          TEXT    NOT NULL UNIQUE,
        uid         TEXT    NOT NULL,
        title       TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        search_text TEXT    NOT NULL DEFAULT '',
        category_id TEXT,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        deleted_at  TEXT,
        sync_status INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    // A listagem sempre filtra por usuário e por lixeira; a pesquisa e a
    // ordenação acontecem sobre esse subconjunto.
    await db.execute(
      'CREATE INDEX idx_notes_uid_deleted ON notes (uid, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_notes_sync_status ON notes (sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_categories_uid ON categories (uid, is_deleted)',
    );
  }

  /// Migração do esquema antigo sem perder as notas já gravadas.
  ///
  /// A tabela da versão 1 não tinha UUID nem datas em formato comparável,
  /// então as linhas existentes são copiadas para a nova tabela recebendo:
  ///
  /// * um UUID novo (gerado aqui, no Dart);
  /// * `created_at`/`updated_at` convertidos do texto `dd/MM/yyyy HH:mm`;
  /// * `sync_status = pendingUpsert`, para que o primeiro login já envie
  ///   essas notas antigas para o Firestore.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2) return;

    final legacyNotes = await db.query('notes');

    await db.execute('ALTER TABLE notes RENAME TO notes_v1');

    await _createCategoriesTable(db);
    await _createNotesTable(db);
    await _createIndexes(db);

    final batch = db.batch();

    for (final row in legacyNotes) {
      final parsed = _parseLegacyDate(row['date'] as String?);
      final timestamp = parsed.toUtc().toIso8601String();

      final title = row['title'] as String? ?? '';
      final content = row['content'] as String? ?? '';

      batch.insert('notes', {
        'id': _uuid.v4(),
        'uid': row['uid'] as String? ?? '',
        'title': title,
        'content': content,
        'search_text': TextNormalizer.forNote(title: title, content: content),
        'category_id': null,
        'created_at': timestamp,
        'updated_at': timestamp,
        'is_deleted': 0,
        'deleted_at': null,
        'sync_status': SyncStatus.pendingUpsert.code,
      });
    }

    await batch.commit(noResult: true);

    await db.execute('DROP TABLE notes_v1');
  }

  /// Converte o texto `dd/MM/yyyy HH:mm` usado na versão 1.
  static DateTime _parseLegacyDate(String? value) {
    if (value == null || value.trim().isEmpty) return DateTime.now();

    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{2}):(\d{2}))?$',
    ).firstMatch(value.trim());

    if (match == null) return DateTime.now();

    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.tryParse(match.group(4) ?? '0') ?? 0,
      int.tryParse(match.group(5) ?? '0') ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Notas
  // ---------------------------------------------------------------------------

  /// Grava a nota criando ou substituindo a linha de mesmo UUID.
  ///
  /// `ON CONFLICT REPLACE` sobre a coluna única `id` deixa a operação
  /// idempotente: o mesmo método serve para o insert do formulário e para o
  /// registro que chega do Firestore durante a sincronização.
  Future<void> upsertNote(Note note) async {
    final db = await database;

    await db.insert(
      'notes',
      note.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertNotes(Iterable<Note> notes) async {
    if (notes.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final note in notes) {
      batch.insert(
        'notes',
        note.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Busca as notas de um usuário aplicando filtro, pesquisa e ordenação.
  ///
  /// [query] procura em título **e** conteúdo, sem diferenciar maiúsculas
  /// (`LIKE` com `COLLATE NOCASE`). A pesquisa roda no SQLite, que já contém
  /// tudo que veio da nuvem, então encontra notas locais e sincronizadas.
  Future<List<Note>> getNotes({
    required String uid,
    bool onlyDeleted = false,
    String? categoryId,
    String query = '',
    NoteSort sort = NoteSort.updatedDesc,
  }) async {
    final db = await database;

    final where = <String>['uid = ?', 'is_deleted = ?'];
    final args = <Object?>[uid, onlyDeleted ? 1 : 0];

    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }

    final term = query.trim();

    if (term.isNotEmpty) {
      // Tanto a coluna quanto o termo passam pela mesma normalização, por
      // isso a pesquisa ignora maiúsculas E acentos.
      where.add('search_text LIKE ?');
      args.add('%${TextNormalizer.normalize(term)}%');
    }

    final rows = await db.query(
      'notes',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: sort.orderBy,
    );

    return rows.map(Note.fromLocalMap).toList();
  }

  Future<Note?> getNoteById(String id) async {
    final db = await database;

    final rows = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Note.fromLocalMap(rows.first);
  }

  /// Quantidade de notas por categoria, usada nos chips de filtro.
  Future<Map<String, int>> countNotesByCategory(String uid) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT category_id, COUNT(*) AS total
      FROM notes
      WHERE uid = ? AND is_deleted = 0
      GROUP BY category_id
      ''',
      [uid],
    );

    final result = <String, int>{};

    for (final row in rows) {
      final categoryId = row['category_id'] as String?;
      if (categoryId == null) continue;

      result[categoryId] = (row['total'] as int?) ?? 0;
    }

    return result;
  }

  Future<int> countTrashedNotes(String uid) async {
    final db = await database;

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM notes WHERE uid = ? AND is_deleted = 1',
      [uid],
    );

    return (rows.first['total'] as int?) ?? 0;
  }

  /// Remove a linha do banco local em definitivo.
  Future<void> hardDeleteNote(String id) async {
    final db = await database;

    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Notas com operação pendente de envio ao Firestore.
  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await database;

    final rows = await db.query(
      'notes',
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.synced.code],
      orderBy: 'updated_at ASC',
    );

    return rows.map(Note.fromLocalMap).toList();
  }

  Future<void> markNoteSynced(String id) async {
    final db = await database;

    await db.update(
      'notes',
      {'sync_status': SyncStatus.synced.code},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPendingNotes(String uid) async {
    final db = await database;

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM notes WHERE uid = ? AND sync_status != ?',
      [uid, SyncStatus.synced.code],
    );

    return (rows.first['total'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Categorias
  // ---------------------------------------------------------------------------

  Future<void> upsertCategory(NoteCategory category) async {
    final db = await database;

    await db.insert(
      'categories',
      category.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCategories(Iterable<NoteCategory> categories) async {
    if (categories.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final category in categories) {
      batch.insert(
        'categories',
        category.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<NoteCategory>> getCategories(String uid) async {
    final db = await database;

    final rows = await db.query(
      'categories',
      where: 'uid = ? AND is_deleted = 0',
      whereArgs: [uid],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(NoteCategory.fromLocalMap).toList();
  }

  Future<NoteCategory?> getCategoryById(String id) async {
    final db = await database;

    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return NoteCategory.fromLocalMap(rows.first);
  }

  Future<void> hardDeleteCategory(String id) async {
    final db = await database;

    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Desassocia a categoria das notas que a usavam.
  ///
  /// As notas afetadas voltam para `pendingUpsert` porque o campo
  /// `categoryId` mudou e precisa ser replicado na nuvem.
  Future<void> detachCategoryFromNotes(String categoryId) async {
    final db = await database;

    await db.update(
      'notes',
      {
        'category_id': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': SyncStatus.pendingUpsert.code,
      },
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<List<NoteCategory>> getPendingCategories(String uid) async {
    final db = await database;

    final rows = await db.query(
      'categories',
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.synced.code],
      orderBy: 'updated_at ASC',
    );

    return rows.map(NoteCategory.fromLocalMap).toList();
  }

  Future<void> markCategorySynced(String id) async {
    final db = await database;

    await db.update(
      'categories',
      {'sync_status': SyncStatus.synced.code},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
