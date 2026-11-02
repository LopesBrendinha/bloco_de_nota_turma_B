import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';

Note note({
  String uid = 'ana',
  String cloudId = 'nota-1',
  int created = 1000,
  int updated = 1000,
  String title = 'Revisão',
  String content = 'Estudar SQLite',
  String category = 'Estudos',
  String change = 'mudanca-1',
}) => Note(
  cloudId: cloudId,
  uid: uid,
  title: title,
  content: content,
  category: category,
  createdAt: created,
  updatedAt: updated,
  changeId: change,
);

class MemoryCloud implements NotesCloud {
  final Map<String, Note> notes = {};
  bool offline = false;
  Future<void> Function()? duringSend;

  @override
  Future<Note> send(Note note) async {
    if (offline) throw const SocketException('Sem conexão');
    await duringSend?.call();
    final key = '${note.uid}/${note.cloudId}';
    final remote = notes[key];
    final winner =
        remote != null &&
            (remote.updatedAt > note.updatedAt ||
                (remote.updatedAt == note.updatedAt &&
                    remote.changeId.compareTo(note.changeId) > 0))
        ? remote
        : note;
    notes[key] = winner.copyWith(synced: true);
    return notes[key]!;
  }

  @override
  Future<List<Note>> fetch(String uid) async {
    if (offline) throw const SocketException('Sem conexão');
    return notes.values.where((note) => note.uid == uid).toList();
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseHelper db;
  late MemoryCloud cloud;
  late SyncService sync;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('notas-test-');
    db = DatabaseHelper(
      factory: databaseFactoryFfi,
      fileName: '${directory.path}/notes.db',
    );
    cloud = MemoryCloud();
    sync = SyncService(
      database: db,
      cloud: cloud,
      uid: 'ana',
      sessionIsActive: () => true,
    );
  });
  tearDown(() async {
    sync.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'pesquisa título e conteúdo sem diferenciar maiúsculas ou acentos',
    () async {
      await db.saveNote(note());
      expect(
        (await db.getNotes('ana', query: 'REVISAO')).single.title,
        'Revisão',
      );
      expect((await db.getNotes('ana', query: 'sqlite')).length, 1);
      expect(await db.getNotes('ana', query: 'sem resultado'), isEmpty);
      expect(await db.getNotes('ana', category: 'Trabalho'), isEmpty);
    },
  );

  test(
    'consultas, categorias e alterações ficam isoladas por usuário',
    () async {
      await db.saveNote(note());
      await db.saveNote(note(uid: 'bia', category: 'Viagem'));
      expect((await db.getNotes('ana')).length, 1);
      expect(await db.getCategories('ana'), isNot(contains('Viagem')));
      final ana = (await db.getNotes('ana')).single;
      await db.saveNote(
        note(uid: 'bia').copyWith(id: ana.id, title: 'Outra pessoa'),
      );
      expect((await db.getNotes('ana')).single.title, 'Revisão');
    },
  );

  test('arquivar, desarquivar e ordenar são operações persistentes', () async {
    await db.saveNote(note(cloudId: 'a', created: 1000, updated: 3000));
    await db.saveNote(note(cloudId: 'b', created: 2000, updated: 2000));
    expect((await db.getNotes('ana')).first.cloudId, 'a');
    expect((await db.getNotes('ana', byCreation: true)).first.cloudId, 'b');
    final original = (await db.getNotes('ana')).first;
    await db.saveNote(original.copyWith(archived: true));
    expect((await db.getNotes('ana')).length, 1);
    final archived = (await db.getNotes('ana', archived: true)).single;
    await db.saveNote(archived.copyWith(archived: false));
    expect((await db.getNotes('ana')).length, 2);
  });

  test(
    'envia criação, edição e exclusão e recupera em outra instalação',
    () async {
      await db.saveNote(note());
      await sync.sync();
      expect(await db.pendingNotes('ana'), isEmpty);
      expect(cloud.notes['ana/nota-1']!.title, 'Revisão');
      final original = (await db.getNotes('ana')).single;
      await db.saveNote(
        original.copyWith(
          title: 'Revisão final',
          updatedAt: 2000,
          changeId: 'mudanca-2',
          synced: false,
        ),
      );
      await sync.sync();
      final second = DatabaseHelper(
        factory: databaseFactoryFfi,
        fileName: '${directory.path}/outra-instalacao.db',
      );
      final secondSync = SyncService(
        database: second,
        cloud: cloud,
        uid: 'ana',
        sessionIsActive: () => true,
      );
      try {
        await secondSync.sync();
        expect((await second.getNotes('ana')).single.title, 'Revisão final');
        final edited = (await db.getNotes('ana')).single;
        await db.saveNote(
          edited.copyWith(
            deleted: true,
            title: '',
            content: '',
            updatedAt: 3000,
            changeId: 'mudanca-3',
            synced: false,
          ),
        );
        await sync.sync();
        await secondSync.sync();
        expect(await second.getNotes('ana'), isEmpty);
        expect(cloud.notes['ana/nota-1']!.deleted, isTrue);
        expect(cloud.notes['ana/nota-1']!.content, isEmpty);
      } finally {
        secondSync.dispose();
        await second.close();
      }
    },
  );

  test(
    'fila sobrevive ao fechamento do banco e é reenviada após erro de conexão',
    () async {
      await db.saveNote(note());
      cloud.offline = true;
      await sync.sync();
      expect(sync.error, isNotNull);
      expect(sync.pending, 1);
      await db.close();
      expect((await db.pendingNotes('ana')).length, 1);
      cloud.offline = false;
      await sync.sync();
      expect(sync.error, isNull);
      expect(await db.pendingNotes('ana'), isEmpty);
    },
  );

  test(
    'edição feita durante envio não é marcada como sincronizada por engano',
    () async {
      await db.saveNote(note());
      cloud.duringSend = () async {
        final original = (await db.getNotes('ana')).single;
        await db.saveNote(
          original.copyWith(
            title: 'Alterada durante envio',
            updatedAt: 2000,
            changeId: 'mudanca-2',
            synced: false,
          ),
        );
      };
      await sync.sync();
      expect(
        (await db.pendingNotes('ana')).single.title,
        'Alterada durante envio',
      );
      cloud.duringSend = null;
      await sync.sync();
      expect(await db.pendingNotes('ana'), isEmpty);
      expect(cloud.notes['ana/nota-1']!.title, 'Alterada durante envio');
    },
  );

  test(
    'conflito mantém a versão mais recente e não ressuscita exclusão antiga',
    () async {
      await db.saveNote(note());
      cloud.notes['ana/nota-1'] = note(
        updated: 5000,
        title: '',
        content: '',
        change: 'remota',
      ).copyWith(deleted: true, synced: true);
      await sync.sync();
      expect(await db.getNotes('ana'), isEmpty);
      expect(await db.pendingNotes('ana'), isEmpty);
    },
  );

  test(
    'sincronização interrompida por troca de conta não aceita a resposta',
    () async {
      var active = true;
      sync.dispose();
      sync = SyncService(
        database: db,
        cloud: cloud,
        uid: 'ana',
        sessionIsActive: () => active,
      );
      await db.saveNote(note());
      cloud.duringSend = () async {
        active = false;
      };
      await sync.sync();
      expect((await db.pendingNotes('ana')).length, 1);
    },
  );

  test(
    'migração preserva notas da versão 1 e prepara envio ao Firestore',
    () async {
      await db.close();
      final legacy = await databaseFactoryFfi.openDatabase(
        '${directory.path}/notes.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) => database.execute('''
        CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL,
          title TEXT NOT NULL, content TEXT NOT NULL, date TEXT NOT NULL)
      '''),
        ),
      );
      await legacy.insert('notes', {
        'uid': 'ana',
        'title': 'Nota da aula',
        'content': 'Preservar este texto',
        'date': '10/10/2026 14:30',
      });
      await legacy.close();
      final migrated = (await db.getNotes('ana')).single;
      expect(migrated.title, 'Nota da aula');
      expect(migrated.date, '10/10/2026 14:30');
      expect(migrated.cloudId, hasLength(36));
      expect(migrated.synced, isFalse);
      await sync.sync();
      expect(cloud.notes.values.single.content, 'Preservar este texto');
    },
  );
}
