import 'dart:math';

import 'package:blocodenotasturmab/models/note.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

enum NoteOrder { updated, created }

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _database;

  DatabaseHelper._init() : _factory = null, _path = null;

  // Permite testar o mesmo SQL em um banco temporário.
  DatabaseHelper.forTesting(DatabaseFactory factory, String path)
    : _factory = factory,
      _path = path;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = _initDB();
    try {
      return await _database!;
    } catch (_) {
      // Uma falha ao abrir não deve bloquear as próximas tentativas.
      _database = null;
      rethrow;
    }
  }

  Future<Database> _initDB() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? join(await factory.getDatabasesPath(), 'notes.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL,
            remoteId TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Pessoal',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            pendingSync INTEGER NOT NULL DEFAULT 1,
            UNIQUE(uid, remoteId)
          )
        ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE notes ADD COLUMN remoteId TEXT');
            await db.execute(
              "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Pessoal'",
            );
            await db.execute(
              'ALTER TABLE notes ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE notes ADD COLUMN pendingSync INTEGER NOT NULL DEFAULT 1',
            );
            for (final row in await db.query('notes')) {
              final date = _oldDate(row['date'] as String);
              await db.update(
                'notes',
                {
                  'remoteId': Note.newRemoteId(),
                  'createdAt': date,
                  'updatedAt': date,
                },
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
            await db.execute(
              'CREATE UNIQUE INDEX notes_remote ON notes(uid, remoteId)',
            );
          }
        },
      ),
    );
  }

  static int _oldDate(String text) {
    final parts = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
    ).firstMatch(text);
    if (parts == null) return DateTime.now().microsecondsSinceEpoch;
    return DateTime(
      int.parse(parts[3]!),
      int.parse(parts[2]!),
      int.parse(parts[1]!),
      int.parse(parts[4]!),
      int.parse(parts[5]!),
    ).microsecondsSinceEpoch;
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert('notes', note.copyWith(pendingSync: true).toMap());
  }

  Future<List<Note>> getNotes(
    String uid, {
    String search = '',
    bool archived = false,
    NoteOrder order = NoteOrder.updated,
  }) async {
    final db = await database;
    final rows = await db.query(
      'notes',
      where: 'uid = ? AND deleted = 0 AND archived = ?',
      whereArgs: [uid, archived ? 1 : 0],
      orderBy:
          '${order == NoteOrder.updated ? 'updatedAt' : 'createdAt'} DESC, id DESC',
    );
    final query = search.trim().toLowerCase();
    // A pesquisa usa a mesma cópia local que recebe as notas da nuvem.
    return rows
        .map(Note.fromMap)
        .where(
          (note) =>
              note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final db = await database;
    final rows = await db.query(
      'notes',
      columns: ['category'],
      distinct: true,
      where: 'uid = ? AND deleted = 0',
      whereArgs: [uid],
    );
    return ({
      'Estudos',
      'Trabalho',
      'Pessoal',
      ...rows.map((row) => row['category'] as String),
    }.toList()..sort());
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(
      'notes',
      note.copyWith(pendingSync: true).toMap(),
      where: 'id = ? AND uid = ? AND deleted = 0',
      whereArgs: [note.id, note.uid],
    );
  }

  Future<int> setArchived(Note note, bool archived) async {
    final db = await database;
    return db.update(
      'notes',
      {
        'archived': archived ? 1 : 0,
        'updatedAt': max(
          DateTime.now().microsecondsSinceEpoch,
          note.updatedAt + 1,
        ),
        'pendingSync': 1,
      },
      where: 'id = ? AND uid = ? AND deleted = 0',
      whereArgs: [note.id, note.uid],
    );
  }

  Future<int> deleteNote(Note note) async {
    final db = await database;
    // Apagamos o conteúdo, mas guardamos a exclusão para os outros aparelhos.
    return db.update(
      'notes',
      {
        'title': '',
        'content': '',
        'category': '',
        'archived': 0,
        'deleted': 1,
        'pendingSync': 1,
        'updatedAt': max(
          DateTime.now().microsecondsSinceEpoch,
          note.updatedAt + 1,
        ),
      },
      where: 'id = ? AND uid = ?',
      whereArgs: [note.id, note.uid],
    );
  }

  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await database;
    return (await db.query(
      'notes',
      where: 'uid = ? AND pendingSync = 1',
      whereArgs: [uid],
    )).map(Note.fromMap).toList();
  }

  Future<void> applyRemote(Note note, {int? sentUpdatedAt}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        where: 'uid = ? AND remoteId = ?',
        whereArgs: [note.uid, note.remoteId],
      );
      if (rows.isEmpty) {
        await txn.insert('notes', note.copyWith(pendingSync: false).toMap());
        return;
      }
      final local = Note.fromMap(rows.single);
      // Uma edição feita durante o envio precisa continuar pendente.
      if (local.pendingSync && local.updatedAt != sentUpdatedAt) return;
      if (!local.pendingSync &&
          !note.deleted &&
          local.updatedAt > note.updatedAt) {
        return;
      }
      await txn.update(
        'notes',
        note.copyWith(id: local.id, pendingSync: false).toMap(),
        where: 'id = ? AND uid = ?',
        whereArgs: [local.id, local.uid],
      );
    });
  }

  Future<void> close() async {
    if (_database != null) await (await _database!).close();
    _database = null;
  }
}
