import 'package:blocodenotasturmab/models/note.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

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
    if (kIsWeb) {
      return await databaseFactoryFfiWeb.openDatabase(
        fileName,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    }

    final dbPath = await getDatabasesPath();

    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 4,
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
        category TEXT NOT NULL DEFAULT 'Sem categoria',
        checklist TEXT NOT NULL DEFAULT '[]',
        remoteId TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX notes_remote_id ON notes(uid, remoteId)',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN remoteId TEXT');
      await db.execute(
        'ALTER TABLE notes ADD COLUMN pendingSync INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN revision INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE UNIQUE INDEX notes_remote_id ON notes(uid, remoteId)',
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Sem categoria'",
      );
    }

    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN checklist TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;

    return await db.insert('notes', {
      ...note.toMap(),
      'pendingSync': 1,
      'revision': 1,
    });
  }

  Future<List<Note>> getNotes(String uid) async {
    final db = await database;

    final result = await db.query(
      'notes',
      where: 'uid = ? AND deleted = 0',
      whereArgs: [uid],
      orderBy: "id DESC",
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await database;

    final result = await db.rawUpdate(
      'UPDATE notes SET title = ?, content = ?, date = ?, category = ?, checklist = ?, '
      'pendingSync = 1, revision = revision + 1 '
      'WHERE id = ? AND uid = ? AND deleted = 0',
      [note.title, note.content, note.date, note.category,
        note.toMap()['checklist'], note.id, note.uid],
    );

    if (result == 0) {
      throw StateError('A nota não está mais disponível.');
    }

    return result;
  }

  Future<int> deleteNote(int id, String uid) async {
    final db = await database;

    return await db.rawUpdate(
      'UPDATE notes SET deleted = 1, pendingSync = 1, '
      'revision = revision + 1 WHERE id = ? AND uid = ?',
      [id, uid],
    );
  }

  Future<Note?> getNote(int id, String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );

    return result.isEmpty ? null : Note.fromMap(result.first);
  }

  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'uid = ? AND pendingSync = 1',
      whereArgs: [uid],
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> assignRemoteId(int id, String uid, String remoteId) async {
    final db = await database;
    await db.update(
      'notes',
      {'remoteId': remoteId},
      where: 'id = ? AND uid = ? AND remoteId IS NULL',
      whereArgs: [id, uid],
    );
  }

  Future<void> markSynced(Note note) async {
    final db = await database;
    const where = 'id = ? AND uid = ? AND revision = ?';
    final whereArgs = [note.id, note.uid, note.revision];

    if (note.deleted) {
      await db.delete('notes', where: where, whereArgs: whereArgs);
    } else {
      await db.update(
        'notes',
        {'pendingSync': 0},
        where: where,
        whereArgs: whereArgs,
      );
    }
  }

  Future<void> mergeCloudNotes(String uid, List<Note> cloudNotes) async {
    if (cloudNotes.any((note) => note.uid != uid)) {
      throw StateError('As notas não pertencem ao usuário conectado.');
    }

    final db = await database;
    await db.transaction((transaction) async {
      final localNotes = await transaction.query(
        'notes',
        where: 'uid = ?',
        whereArgs: [uid],
      );
      final cloudIds = cloudNotes.map((note) => note.remoteId).toSet();

      for (final cloudNote in cloudNotes) {
        final matching = localNotes.where(
          (note) => note['remoteId'] == cloudNote.remoteId,
        );
        final localNote = matching.isEmpty ? null : matching.first;

        if (cloudNote.deleted) {
          await transaction.delete(
            'notes',
            where: 'uid = ? AND remoteId = ?',
            whereArgs: [uid, cloudNote.remoteId],
          );
        } else if (localNote == null) {
          await transaction.insert('notes', cloudNote.toMap());
        } else if (localNote['pendingSync'] == 0) {
          await transaction.update(
            'notes',
            {...cloudNote.toMap(), 'id': localNote['id']},
            where: 'id = ? AND uid = ?',
            whereArgs: [localNote['id'], uid],
          );
        }
      }

      for (final localNote in localNotes) {
        if (localNote['pendingSync'] == 0 &&
            localNote['remoteId'] != null &&
            !cloudIds.contains(localNote['remoteId'])) {
          await transaction.delete(
            'notes',
            where: 'id = ? AND uid = ?',
            whereArgs: [localNote['id'], uid],
          );
        }
      }
    });
  }
}
