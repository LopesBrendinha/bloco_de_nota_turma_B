import 'dart:io';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('migração v1 -> v2 preserva as notas antigas', () async {
    final dir = await Directory.systemTemp.createTemp('notes_test');
    final path = p.join(dir.path, 'notes.db');

    // Banco no formato original do projeto (versão 1).
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, '
            'title TEXT NOT NULL, content TEXT NOT NULL, date TEXT NOT NULL)',
          );
          await db.insert('notes', {
            'uid': 'u1',
            'title': 'Antiga',
            'content': 'conteúdo',
            'date': '05/03/2026 14:30',
          });
        },
      ),
    );
    await v1.close();

    final helper = DatabaseHelper(path: path, factory: databaseFactoryFfi);
    final note = (await helper.getNotes('u1')).single;

    expect(note.title, 'Antiga');
    expect(note.category, 'Geral');
    expect(note.synced, isFalse); // vai subir para a nuvem no próximo sync
    expect(note.updatedAt, DateTime(2026, 3, 5, 14, 30));
    expect(note.remoteId, isNotEmpty);

    await helper.close();
    await dir.delete(recursive: true);
  });
}
