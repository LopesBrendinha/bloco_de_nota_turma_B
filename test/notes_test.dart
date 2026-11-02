import 'dart:async';
import 'dart:io';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Só substitui a conexão de rede; o banco usado nos testes é SQLite.
class TestFirestore extends FirestoreService {
  final Map<String, Note> notes = {};
  final Set<String> rejectedNotes = {};
  bool offline = false;
  int writes = 0;
  Completer<void>? waitForWrite;

  @override
  Future<Note> saveNote(Note note) async {
    if (offline) throw StateError('Sem conexão');
    if (rejectedNotes.contains(note.remoteId)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    writes++;
    if (waitForWrite != null) await waitForWrite!.future;
    final saved = Note.fromFirestore(note.remoteId, note.toFirestore());
    notes['${note.uid}/${note.remoteId}'] = saved;
    return saved;
  }

  @override
  Future<List<Note>> getNotes(String uid) async {
    if (offline) throw StateError('Sem conexão');
    return notes.values.where((note) => note.uid == uid).toList();
  }
}

Note example({
  String remoteId = 'nota-1',
  String uid = 'ana',
  String title = 'Prova',
  String content = 'Revisar matemática',
  int createdAt = 100,
  int updatedAt = 100,
}) => Note(
  remoteId: remoteId,
  uid: uid,
  title: title,
  content: content,
  category: 'Estudos',
  createdAt: createdAt,
  updatedAt: updatedAt,
);

void main() {
  sqfliteFfiInit();
  late DatabaseHelper database;
  late Directory directory;
  late TestFirestore remote;
  late SyncService sync;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bloco_notas_test_');
    database = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      '${directory.path}/notes.db',
    );
    remote = TestFirestore();
    sync = SyncService(database: database, firestore: remote);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('uma falha na abertura do banco permite tentar novamente', () async {
    final blockedPath = Directory('${directory.path}/notes.db');
    await blockedPath.create();
    await expectLater(
      database.getNotes('ana'),
      throwsA(isA<DatabaseException>()),
    );
    await blockedPath.delete();
    await database.insertNote(example());
    expect(await database.getNotes('ana'), hasLength(1));
  });

  test(
    'uma nota recusada não bloqueia as outras nem a recuperação da nuvem',
    () async {
      await database.insertNote(example(remoteId: 'recusada'));
      await database.insertNote(example(remoteId: 'valida'));
      remote.rejectedNotes.add('recusada');
      remote.notes['ana/da-nuvem'] = example(
        remoteId: 'da-nuvem',
      ).copyWith(pendingSync: false);
      await expectLater(
        sync.synchronize('ana'),
        throwsA(isA<PartialSyncException>()),
      );
      expect(remote.notes.containsKey('ana/valida'), isTrue);
      expect(
        (await database.getPendingNotes('ana')).single.remoteId,
        'recusada',
      );
      expect(
        (await database.getNotes('ana')).map((note) => note.remoteId),
        contains('da-nuvem'),
      );
      remote.rejectedNotes.clear();
      await sync.synchronize('ana');
      expect(await database.getPendingNotes('ana'), isEmpty);
    },
  );

  test(
    'cria, consulta, pesquisa título e conteúdo e separa usuários',
    () async {
      await database.insertNote(example());
      await database.insertNote(example(uid: 'bia', title: 'Nota da Bia'));
      expect((await database.getNotes('ana')).single.title, 'Prova');
      expect(await database.getNotes('ana', search: 'PROVA'), hasLength(1));
      expect(
        await database.getNotes('ana', search: 'MATEMÁTICA'),
        hasLength(1),
      );
      expect(await database.getNotes('ana', search: 'Bia'), isEmpty);
      expect(await database.getNotes('ana', search: "' OR 1=1 --"), isEmpty);
    },
  );

  test('edita sem mudar a criação e ordena pelas duas datas', () async {
    await database.insertNote(example());
    await database.insertNote(
      example(remoteId: 'nota-2', createdAt: 200, updatedAt: 200),
    );
    final old = (await database.getNotes('ana')).last;
    await database.updateNote(old.copyWith(title: 'Revisão', updatedAt: 300));
    expect((await database.getNotes('ana')).first.title, 'Revisão');
    expect(
      (await database.getNotes('ana', order: NoteOrder.created)).first.remoteId,
      'nota-2',
    );
    expect((await database.getNotes('ana')).first.createdAt, 100);
  });

  test('não altera nem exclui uma nota usando outro uid', () async {
    final id = await database.insertNote(example());
    final otherUser = example(uid: 'bia').copyWith(id: id);
    expect(await database.updateNote(otherUser), 0);
    expect(await database.setArchived(otherUser, true), 0);
    expect(await database.deleteNote(otherUser), 0);
    expect(await database.getNotes('ana'), hasLength(1));
  });

  test('arquiva, pesquisa nas arquivadas e desarquiva sem apagar', () async {
    await database.insertNote(example());
    var note = (await database.getNotes('ana')).single;
    await database.setArchived(note, true);
    expect(await database.getNotes('ana'), isEmpty);
    note = (await database.getNotes(
      'ana',
      archived: true,
      search: 'prova',
    )).single;
    expect(note.content, 'Revisar matemática');
    await database.setArchived(note, false);
    expect(await database.getNotes('ana'), hasLength(1));
    expect(await database.getNotes('ana', archived: true), isEmpty);
  });

  test('categoria personalizada fica disponível só ao seu usuário', () async {
    await database.insertNote(example().copyWith(category: 'Faculdade'));
    expect(await database.getCategories('ana'), contains('Faculdade'));
    expect(await database.getCategories('bia'), isNot(contains('Faculdade')));
    await database.close();
    expect((await database.getNotes('ana')).single.category, 'Faculdade');
  });

  test('erro de conexão preserva a fila e a próxima tentativa envia', () async {
    await database.insertNote(example());
    remote.offline = true;
    await expectLater(sync.synchronize('ana'), throwsStateError);
    expect(await database.getPendingNotes('ana'), hasLength(1));
    expect(await database.getNotes('ana'), hasLength(1));
    remote.offline = false;
    await sync.synchronize('ana');
    expect(await database.getPendingNotes('ana'), isEmpty);
    expect(remote.notes, hasLength(1));
    await sync.synchronize('ana');
    expect(remote.writes, 1);
  });

  test('outra instalação recupera, edita e devolve a alteração', () async {
    await database.insertNote(example());
    await sync.synchronize('ana');
    final second = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      '${directory.path}/second.db',
    );
    try {
      final secondSync = SyncService(database: second, firestore: remote);
      await secondSync.synchronize('ana');
      final note = (await second.getNotes('ana')).single;
      await second.updateNote(
        note.copyWith(content: 'Conteúdo editado', updatedAt: 200),
      );
      await secondSync.synchronize('ana');
      await sync.synchronize('ana');
      expect(
        (await database.getNotes('ana')).single.content,
        'Conteúdo editado',
      );
      expect(await database.getNotes('bia'), isEmpty);
    } finally {
      await second.close();
    }
  });

  test(
    'exclusão sem conexão limpa o conteúdo e depois alcança outro banco',
    () async {
      await database.insertNote(example());
      await sync.synchronize('ana');
      final second = DatabaseHelper.forTesting(
        databaseFactoryFfi,
        '${directory.path}/second.db',
      );
      try {
        final secondSync = SyncService(database: second, firestore: remote);
        await secondSync.synchronize('ana');
        await database.deleteNote((await database.getNotes('ana')).single);
        remote.offline = true;
        await expectLater(sync.synchronize('ana'), throwsStateError);
        expect(await database.getNotes('ana'), isEmpty);
        final deleted = (await database.getPendingNotes('ana')).single;
        expect(deleted.deleted, isTrue);
        expect(deleted.content, isEmpty);
        remote.offline = false;
        await sync.synchronize('ana');
        await secondSync.synchronize('ana');
        expect(await second.getNotes('ana'), isEmpty);
        expect(remote.notes.values.single.deleted, isTrue);
        expect(remote.notes.values.single.content, isEmpty);
      } finally {
        await second.close();
      }
    },
  );

  test('arquivamento também é sincronizado', () async {
    await database.insertNote(example());
    await database.setArchived((await database.getNotes('ana')).single, true);
    await sync.synchronize('ana');
    expect(remote.notes.values.single.archived, isTrue);
    expect(await database.getNotes('ana', archived: true), hasLength(1));
  });

  test('uma edição durante o envio continua pendente', () async {
    await database.insertNote(example());
    final note = (await database.getNotes('ana')).single;
    remote.waitForWrite = Completer<void>();
    final first = sync.synchronize('ana');
    final duplicate = sync.synchronize('ana');
    expect(identical(first, duplicate), isTrue);
    while (remote.writes == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await database.updateNote(
      note.copyWith(content: 'Edição durante envio', updatedAt: 200),
    );
    remote.waitForWrite!.complete();
    await first;
    expect(
      (await database.getPendingNotes('ana')).single.content,
      'Edição durante envio',
    );
    remote.waitForWrite = null;
    await sync.synchronize('ana');
    expect(remote.notes.values.single.content, 'Edição durante envio');
    expect(await database.getPendingNotes('ana'), isEmpty);
  });

  test('uma resposta remota não apaga uma edição ainda não enviada', () async {
    await database.insertNote(example(updatedAt: 200));
    await database.applyRemote(
      example(updatedAt: 100).copyWith(pendingSync: false),
    );
    expect((await database.getNotes('ana')).single.updatedAt, 200);
    expect(await database.getPendingNotes('ana'), hasLength(1));
  });

  test(
    'migra o banco original sem perder notas e preserva a data antiga',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
        '${directory.path}/notes.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'uid TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, date TEXT NOT NULL)',
            );
          },
        ),
      );
      await old.insert('notes', {
        'uid': 'ana',
        'title': 'Antiga',
        'content': 'Conteúdo original',
        'date': '20/10/2026 14:30',
      });
      await old.close();
      final note = (await database.getNotes('ana')).single;
      expect(note.title, 'Antiga');
      expect(
        note.createdAt,
        DateTime(2026, 10, 20, 14, 30).microsecondsSinceEpoch,
      );
      expect(note.category, 'Pessoal');
      expect(note.remoteId, hasLength(32));
      expect(note.pendingSync, isTrue);
      await sync.synchronize('ana');
      expect(remote.notes, hasLength(1));
    },
  );
}
