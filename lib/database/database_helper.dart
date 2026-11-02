import 'package:diacritic/diacritic.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper();
  final DatabaseFactory? factory;
  final String fileName;
  Database? _database;
  Future<Database>? _opening;

  DatabaseHelper({this.factory, this.fileName = 'notes.db'});

  Future<Database> get database async =>
      _database ??= await (_opening ??= _open());

  Future<Database> _open() async {
    final dbFactory = factory ?? databaseFactory;
    final path = fileName == inMemoryDatabasePath
        ? fileName
        : join(await dbFactory.getDatabasesPath(), fileName);
    return dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL,
            date TEXT NOT NULL, cloudId TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Pessoal',
            createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            synced INTEGER NOT NULL DEFAULT 0, changeId TEXT NOT NULL,
            UNIQUE(uid, cloudId)
          )
        ''');
          await db.execute('CREATE INDEX notes_owner ON notes(uid, deleted)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            for (final column in [
              "cloudId TEXT NOT NULL DEFAULT ''",
              "category TEXT NOT NULL DEFAULT 'Pessoal'",
              'createdAt INTEGER NOT NULL DEFAULT 0',
              'updatedAt INTEGER NOT NULL DEFAULT 0',
              'archived INTEGER NOT NULL DEFAULT 0',
              'deleted INTEGER NOT NULL DEFAULT 0',
              'synced INTEGER NOT NULL DEFAULT 0',
              "changeId TEXT NOT NULL DEFAULT ''",
            ]) {
              await db.execute('ALTER TABLE notes ADD COLUMN $column');
            }
            for (final row in await db.query('notes')) {
              final parts = RegExp(
                r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
              ).firstMatch(row['date'] as String);
              final date = parts == null
                  ? DateTime.now()
                  : DateTime(
                      int.parse(parts[3]!),
                      int.parse(parts[2]!),
                      int.parse(parts[1]!),
                      int.parse(parts[4]!),
                      int.parse(parts[5]!),
                    );
              await db.update(
                'notes',
                {
                  'cloudId': const Uuid().v4(),
                  'changeId': const Uuid().v4(),
                  'createdAt': date.millisecondsSinceEpoch,
                  'updatedAt': date.millisecondsSinceEpoch,
                },
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
            await db.execute(
              'CREATE UNIQUE INDEX notes_cloud ON notes(uid, cloudId)',
            );
            await db.execute('CREATE INDEX notes_owner ON notes(uid, deleted)');
          }
        },
      ),
    );
  }

  Future<void> saveNote(Note note) async {
    final db = await database;
    if (note.id == null) {
      await db.insert('notes', note.toMap());
    } else {
      await db.update(
        'notes',
        note.toMap(),
        where: 'id = ? AND uid = ?',
        whereArgs: [note.id, note.uid],
      );
    }
  }

  Future<List<Note>> getNotes(
    String uid, {
    String query = '',
    String? category,
    bool archived = false,
    bool byCreation = false,
  }) async {
    final rows = await (await database).query(
      'notes',
      where: 'uid = ? AND deleted = 0 AND archived = ?',
      whereArgs: [uid, archived ? 1 : 0],
      orderBy: '${byCreation ? 'createdAt' : 'updatedAt'} DESC, cloudId ASC',
    );
    String normalize(String text) => removeDiacritics(text).toLowerCase();
    final search = normalize(query.trim());
    return rows
        .map(Note.fromMap)
        .where(
          (note) =>
              (category == null || note.category == category) &&
              (normalize(note.title).contains(search) ||
                  normalize(note.content).contains(search)),
        )
        .toList();
  }

  Future<List<String>> getCategories(String uid) async {
    final rows = await (await database).rawQuery(
      'SELECT DISTINCT category FROM notes WHERE uid = ? AND deleted = 0',
      [uid],
    );
    return ({
      'Pessoal',
      'Estudos',
      'Trabalho',
      ...rows.map((row) => row['category'] as String),
    }.toList()..sort());
  }

  Future<List<Note>> pendingNotes(String uid) async {
    final rows = await (await database).query(
      'notes',
      where: 'uid = ? AND synced = 0',
      whereArgs: [uid],
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<void> acceptRemote(Note note, {String? expectedChange}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        where: 'uid = ? AND cloudId = ?',
        whereArgs: [note.uid, note.cloudId],
      );
      if (rows.isEmpty) {
        await txn.insert('notes', note.copyWith(synced: true).toMap());
        return;
      }
      final local = Note.fromMap(rows.single);
      if (expectedChange != null
          ? local.changeId != expectedChange
          : !local.synced) {
        return;
      }
      if (expectedChange == null &&
          (note.updatedAt < local.updatedAt ||
              (note.updatedAt == local.updatedAt &&
                  note.changeId.compareTo(local.changeId) < 0))) {
        return;
      }
      await txn.update(
        'notes',
        note.copyWith(id: local.id, synced: true).toMap(),
        where: 'uid = ? AND cloudId = ?',
        whereArgs: [note.uid, note.cloudId],
      );
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }
}
