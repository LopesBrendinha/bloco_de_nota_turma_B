import 'package:sqflite/sqlite_api.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../utils/date_utils.dart';
import '../utils/id_generator.dart';
import '../utils/text_utils.dart';

/// Tipos de registro que podem aguardar exclusão na nuvem.
enum RemoteCollection { notes, categories }

/// Exclusão feita no aparelho que ainda precisa ser repetida no Firestore.
class PendingDeletion {
  final RemoteCollection collection;
  final String id;

  const PendingDeletion(this.collection, this.id);
}

/// Acesso ao SQLite (padrão DAO): todo o SQL do aplicativo fica nesta classe.
///
/// A fábrica de banco e o caminho vêm de fora para que os testes rodem com
/// um SQLite real, sem precisar de um aparelho.
class DatabaseHelper {
  static const int schemaVersion = 2;

  final DatabaseFactory _factory;
  final String _path;
  Future<Database>? _opening;

  DatabaseHelper(this._factory, this._path);

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() {
    return _factory.openDatabase(
      _path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => _createTables(db),
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        trashed_at INTEGER,
        synced_at INTEGER,
        search_text TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_uid_updated ON notes(uid, updated_at DESC)',
    );
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_deletions(
        collection TEXT NOT NULL,
        doc_id TEXT NOT NULL,
        uid TEXT NOT NULL,
        PRIMARY KEY(collection, doc_id)
      )
    ''');
  }

  /// Migra o banco da versão 1 sem perder as notas que já existem.
  ///
  /// O `onUpgrade` roda dentro de uma transação: se algo falhar, o banco
  /// continua como estava.
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2) return;

    await db.execute('ALTER TABLE notes RENAME TO notes_v1');
    await _createTables(db);

    final oldNotes = await db.query('notes_v1');
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final old in oldNotes) {
      final timestamp = parseLegacyDate(old['date'] as String) ?? now;
      final note = Note(
        id: generateId(),
        uid: old['uid'] as String,
        title: old['title'] as String,
        content: old['content'] as String,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await db.insert('notes', note.toMap());
    }

    await db.execute('DROP TABLE notes_v1');
  }

  // ---------------------------------------------------------------- Notas

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert('notes', note.toMap());
  }

  /// Atualiza uma nota sem mexer em `synced_at`, que só muda quando a
  /// nuvem confirma o recebimento.
  Future<int> updateNote(Note note) async {
    final db = await database;
    final values = note.toMap()..remove('synced_at');
    return db.update('notes', values, where: 'id = ?', whereArgs: [note.id]);
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  /// Notas ativas do usuário, das mais recentes para as mais antigas.
  ///
  /// [query] procura no título e no conteúdo, ignorando maiúsculas e acentos.
  /// Com várias palavras, a nota precisa conter todas.
  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? categoryId,
  }) async {
    final db = await database;
    final where = ['uid = ?', 'trashed_at IS NULL'];
    final args = <Object?>[uid];

    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }

    final terms = normalizeForSearch(
      query,
    ).split(RegExp(r'\s+')).where((term) => term.isNotEmpty);

    for (final term in terms) {
      where.add(r"search_text LIKE ? ESCAPE '\'");
      args.add('%${escapeLike(term)}%');
    }

    final rows = await db.query(
      'notes',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getTrashedNotes(String uid) async {
    final db = await database;
    final rows = await db.query(
      'notes',
      where: 'uid = ? AND trashed_at IS NOT NULL',
      whereArgs: [uid],
      orderBy: 'trashed_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Todas as notas do usuário, inclusive as da lixeira.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await database;
    final rows = await db.query('notes', where: 'uid = ?', whereArgs: [uid]);
    return rows.map(Note.fromMap).toList();
  }

  /// Apaga a nota do aparelho e registra que falta apagar na nuvem.
  ///
  /// As duas operações ficam na mesma transação: se o aplicativo fechar no
  /// meio, a nota não some daqui sem a exclusão ficar registrada.
  Future<void> deleteNote(String uid, String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      await _addPendingDeletion(txn, RemoteCollection.notes, uid, id);
    });
  }

  // ----------------------------------------------------------- Categorias

  Future<void> insertCategory(NoteCategory category) async {
    final db = await database;
    await db.insert('categories', category.toMap());
  }

  Future<List<NoteCategory>> getCategories(String uid) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(NoteCategory.fromMap).toList();
  }

  /// Apaga a categoria e deixa as notas dela sem categoria.
  ///
  /// As notas recebem um novo `updated_at` para que a mudança chegue à nuvem.
  Future<void> deleteCategory(String uid, String id, {DateTime? now}) async {
    final db = await database;
    final current = (now ?? DateTime.now()).millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE notes SET category_id = NULL, '
        'updated_at = MAX(?, updated_at + 1) '
        'WHERE uid = ? AND category_id = ?',
        [current, uid, id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      await _addPendingDeletion(txn, RemoteCollection.categories, uid, id);
    });
  }

  // -------------------------------------------------------- Sincronização

  /// Quantidade de alterações que ainda não chegaram à nuvem.
  Future<int> countPendingChanges(String uid) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM notes
          WHERE uid = ? AND synced_at IS NOT updated_at)
        + (SELECT COUNT(*) FROM categories
          WHERE uid = ? AND synced_at IS NOT updated_at)
        + (SELECT COUNT(*) FROM pending_deletions WHERE uid = ?) AS total
      ''',
      [uid, uid, uid],
    );
    return rows.first['total'] as int;
  }

  Future<List<PendingDeletion>> getPendingDeletions(String uid) async {
    final db = await database;
    final rows = await db.query(
      'pending_deletions',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows
        .map(
          (row) => PendingDeletion(
            RemoteCollection.values.byName(row['collection'] as String),
            row['doc_id'] as String,
          ),
        )
        .toList();
  }

  Future<void> removePendingDeletion(PendingDeletion deletion) async {
    final db = await database;
    await db.delete(
      'pending_deletions',
      where: 'collection = ? AND doc_id = ?',
      whereArgs: [deletion.collection.name, deletion.id],
    );
  }

  Future<void> _addPendingDeletion(
    Transaction txn,
    RemoteCollection collection,
    String uid,
    String id,
  ) {
    return txn.insert('pending_deletions', {
      'collection': collection.name,
      'doc_id': id,
      'uid': uid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Grava uma nota vinda da nuvem.
  ///
  /// [expectedUpdatedAt] é o `updated_at` local visto no início da
  /// sincronização. Se o usuário editou a nota nesse intervalo, nada é
  /// gravado e a edição dele continua pendente.
  Future<void> saveRemoteNote(Note remote, {int? expectedUpdatedAt}) async {
    final db = await database;
    final values = remote.copyWith(syncedAt: remote.updatedAt).toMap();

    if (expectedUpdatedAt == null) {
      await db.insert(
        'notes',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.update(
        'notes',
        values,
        where: 'id = ? AND updated_at = ?',
        whereArgs: [remote.id, expectedUpdatedAt],
      );
    }
  }

  /// Remove uma nota apagada em outro aparelho, se ela não mudou aqui.
  Future<void> removeNoteDeletedRemotely(Note note) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ? AND updated_at = ?',
      whereArgs: [note.id, note.updatedAt],
    );
  }

  /// Registra a versão de [note] como a que a nuvem tem agora.
  ///
  /// Se o usuário editou a nota durante o envio, `updated_at` já é maior que
  /// `synced_at` e a nota continua pendente.
  Future<void> markNoteSynced(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      {'synced_at': note.updatedAt},
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> saveRemoteCategory(
    NoteCategory remote, {
    int? expectedUpdatedAt,
  }) async {
    final db = await database;
    final values = remote.copyWith(syncedAt: remote.updatedAt).toMap();

    if (expectedUpdatedAt == null) {
      await db.insert(
        'categories',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.update(
        'categories',
        values,
        where: 'id = ? AND updated_at = ?',
        whereArgs: [remote.id, expectedUpdatedAt],
      );
    }
  }

  /// Remove uma categoria apagada em outro aparelho.
  ///
  /// As notas não recebem novo `updated_at`, porque o aparelho que apagou a
  /// categoria já enviou essa mudança para a nuvem.
  Future<void> removeCategoryDeletedRemotely(NoteCategory category) async {
    final db = await database;
    await db.transaction((txn) async {
      final removed = await txn.delete(
        'categories',
        where: 'id = ? AND updated_at = ?',
        whereArgs: [category.id, category.updatedAt],
      );
      if (removed > 0) {
        await txn.update(
          'notes',
          {'category_id': null},
          where: 'category_id = ?',
          whereArgs: [category.id],
        );
      }
    });
  }

  Future<void> markCategorySynced(NoteCategory category) async {
    final db = await database;
    await db.update(
      'categories',
      {'synced_at': category.updatedAt},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }
}
