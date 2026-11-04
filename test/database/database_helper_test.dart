import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

Note note(
  String id, {
  String uid = 'ana',
  String title = 'Título',
  String content = 'Conteúdo',
  String? categoryId,
  int updatedAt = 100,
  int? trashedAt,
  int? syncedAt,
}) {
  return Note(
    id: id,
    uid: uid,
    title: title,
    content: content,
    categoryId: categoryId,
    createdAt: 1,
    updatedAt: updatedAt,
    trashedAt: trashedAt,
    syncedAt: syncedAt,
  );
}

void main() {
  late DatabaseHelper database;

  setUp(() async {
    database = await openTestDatabase();
  });

  tearDown(() => database.close());

  group('CRUD', () {
    test('cria, consulta, edita e exclui uma nota', () async {
      await database.insertNote(note('n1'));
      expect((await database.getNote('n1'))!.title, 'Título');

      await database.updateNote(note('n1', title: 'Novo', updatedAt: 200));
      expect((await database.getNote('n1'))!.title, 'Novo');

      await database.deleteNote('ana', 'n1');
      expect(await database.getNote('n1'), isNull);
    });

    test('updateNote não apaga a marca de sincronização', () async {
      await database.saveRemoteNote(note('n1'));

      await database.updateNote(note('n1', title: 'Novo', updatedAt: 200));

      final stored = (await database.getNote('n1'))!;
      expect(stored.syncedAt, 100);
      expect(stored.updatedAt, 200);
    });

    test('um usuário não vê as notas de outro', () async {
      await database.insertNote(note('n1', uid: 'ana'));
      await database.insertNote(note('n2', uid: 'bia'));

      final notes = await database.getNotes('ana');

      expect(notes.map((item) => item.id), ['n1']);
    });

    test('ordena da alteração mais recente para a mais antiga', () async {
      await database.insertNote(note('velha', updatedAt: 100));
      await database.insertNote(note('nova', updatedAt: 300));
      await database.insertNote(note('media', updatedAt: 200));

      final notes = await database.getNotes('ana');

      expect(notes.map((item) => item.id), ['nova', 'media', 'velha']);
    });
  });

  group('pesquisa', () {
    setUp(() async {
      await database.insertNote(
        note('reuniao', title: 'Reunião de equipe', content: 'Pauta do dia'),
      );
      await database.insertNote(
        note('compras', title: 'Mercado', content: 'Comprar PÃO e café'),
      );
      await database.insertNote(
        note('desconto', title: 'Promoção', content: 'Desconto de 50% hoje'),
      );
    });

    Future<List<String>> search(String query, {String? categoryId}) async {
      final notes = await database.getNotes(
        'ana',
        query: query,
        categoryId: categoryId,
      );
      return notes.map((item) => item.id).toList();
    }

    test('encontra pelo título e pelo conteúdo', () async {
      expect(await search('Mercado'), ['compras']);
      expect(await search('Pauta'), ['reuniao']);
    });

    test('ignora maiúsculas e acentos', () async {
      expect(await search('REUNIAO'), ['reuniao']);
      expect(await search('reunião'), ['reuniao']);
      expect(await search('pao'), ['compras']);
    });

    test('com várias palavras, exige todas', () async {
      expect(await search('cafe mercado'), ['compras']);
      expect(await search('cafe equipe'), isEmpty);
    });

    test('trata % e _ como texto comum', () async {
      expect(await search('50%'), ['desconto']);
      expect(await search('%'), ['desconto']);
      expect(await search('_'), isEmpty);
    });

    test('combina pesquisa e categoria', () async {
      await database.insertNote(
        note('estudo', title: 'Café na história', categoryId: 'estudos'),
      );

      expect(await search('cafe', categoryId: 'estudos'), ['estudo']);
    });

    test('não mostra as notas da lixeira', () async {
      await database.insertNote(
        note('apagada', title: 'Mercado antigo', trashedAt: 5),
      );

      expect(await search('mercado'), ['compras']);
    });
  });

  group('lixeira', () {
    test('separa as notas ativas das que estão na lixeira', () async {
      await database.insertNote(note('ativa'));
      await database.insertNote(note('apagada', trashedAt: 5));

      expect((await database.getNotes('ana')).map((n) => n.id), ['ativa']);
      expect((await database.getTrashedNotes('ana')).map((n) => n.id), [
        'apagada',
      ]);
    });
  });

  group('categorias', () {
    test('excluir categoria mantém as notas e as marca como pendentes', () async {
      const category = NoteCategory(
        id: 'c1',
        uid: 'ana',
        name: 'Faculdade',
        updatedAt: 5,
      );
      await database.insertCategory(category);
      await database.saveRemoteNote(note('n1', categoryId: 'c1'));

      await database.deleteCategory(
        'ana',
        'c1',
        now: DateTime.fromMillisecondsSinceEpoch(500),
      );

      final stored = (await database.getNote('n1'))!;
      expect(stored.categoryId, isNull);
      expect(stored.updatedAt, 500);
      expect(await database.getCategories('ana'), isEmpty);
      expect((await database.getPendingDeletions('ana')).single.id, 'c1');
    });
  });

  group('pendências', () {
    test('conta notas, categorias e exclusões', () async {
      await database.insertNote(note('nova'));
      await database.saveRemoteNote(note('sincronizada'));
      await database.saveRemoteNote(note('apagar'));
      await database.deleteNote('ana', 'apagar');
      await database.insertCategory(
        const NoteCategory(id: 'c1', uid: 'ana', name: 'A', updatedAt: 1),
      );

      expect(await database.countPendingChanges('ana'), 3);
      expect(await database.countPendingChanges('bia'), 0);
    });
  });

  group('migração da versão 1', () {
    late String path;

    setUp(() async {
      path = await temporaryDatabasePath();

      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => db.execute('''
            CREATE TABLE notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uid TEXT NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              date TEXT NOT NULL
            )
          '''),
        ),
      );
      await old.insert('notes', {
        'uid': 'ana',
        'title': 'Reunião antiga',
        'content': 'Texto',
        'date': '15/10/2026 08:30',
      });
      await old.insert('notes', {
        'uid': 'ana',
        'title': 'Data inválida',
        'content': 'Outro texto',
        'date': 'sem data',
      });
      await old.close();
    });

    test('preserva as notas e as prepara para sincronizar', () async {
      final migrated = DatabaseHelper(databaseFactoryFfi, path);
      addTearDown(migrated.close);

      final notes = await migrated.getNotes('ana');

      expect(notes, hasLength(2));
      expect(notes.map((n) => n.id).toSet(), hasLength(2));

      final old = notes.singleWhere((n) => n.title == 'Reunião antiga');
      expect(old.date, '15/10/2026 08:30');
      expect(old.id, hasLength(36));
      expect(old.syncedAt, isNull);

      expect(await migrated.getNotes('ana', query: 'reuniao'), hasLength(1));
      expect(await migrated.countPendingChanges('ana'), 2);
    });
  });
}
