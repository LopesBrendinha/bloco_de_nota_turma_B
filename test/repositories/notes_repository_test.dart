import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/repositories/notes_repository.dart';
import 'package:blocodenotasturmab/services/remote_data_source.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_remote_data_source.dart';
import '../support/test_database.dart';

void main() {
  late FakeRemoteDataSource cloud;
  late DatabaseHelper database;
  late NotesRepository repository;

  setUp(() async {
    cloud = FakeRemoteDataSource();
    database = await openTestDatabase();
    repository = NotesRepository(
      database,
      SyncService(database, cloud),
      syncDelay: const Duration(milliseconds: 5),
      retryInterval: const Duration(milliseconds: 20),
    );
    repository.start('ana');
    await repository.syncNow();
  });

  tearDown(() async {
    repository.stop();
    await database.close();
  });

  /// Espera a sincronização agendada terminar.
  Future<void> settle() {
    return Future<void>.delayed(const Duration(milliseconds: 60));
  }

  test('salvar uma nota funciona sem internet', () async {
    cloud.failure = RemoteErrorKind.offline;

    await repository.saveNote(title: 'Título', content: 'Texto');
    await settle();

    expect(await repository.getNotes(), hasLength(1));
    expect(repository.status.isOffline, isTrue);
    expect(repository.status.pendingChanges, 1);
  });

  test('tenta de novo sozinho quando a internet volta', () async {
    cloud.failure = RemoteErrorKind.offline;
    await repository.saveNote(title: 'Título', content: 'Texto');
    await settle();

    cloud.failure = null;
    await settle();

    expect(cloud.notes, hasLength(1));
    expect(repository.status.state, SyncState.synced);
    expect(repository.status.pendingChanges, 0);
  });

  test('salvar envia a nota para a nuvem em segundo plano', () async {
    await repository.saveNote(title: 'Título', content: 'Texto');
    await settle();

    expect(cloud.notes.values.single.uid, 'ana');
  });

  test('editar mantém o ID e a data de criação', () async {
    await repository.saveNote(title: 'Título', content: 'Texto');
    final created = (await repository.getNotes()).single;

    await repository.saveNote(
      id: created.id,
      title: 'Novo',
      content: 'Texto',
      categoryId: 'estudos',
    );

    final edited = (await repository.getNotes()).single;
    expect(edited.id, created.id);
    expect(edited.createdAt, created.createdAt);
    expect(edited.updatedAt, greaterThan(created.updatedAt));
    expect(edited.categoryId, 'estudos');
  });

  test('editar uma nota apagada em outro aparelho não perde o texto', () async {
    await repository.saveNote(
      id: 'apagada-em-outro-aparelho',
      title: 'Título',
      content: 'Texto que não pode sumir',
    );

    expect((await repository.getNotes()).single.content, contains('sumir'));
  });

  group('lixeira', () {
    test('mover e recuperar', () async {
      await repository.saveNote(title: 'Título', content: 'Texto');
      final note = (await repository.getNotes()).single;

      await repository.moveToTrash(note.id);
      expect(await repository.getNotes(), isEmpty);
      expect(await repository.getTrashedNotes(), hasLength(1));

      await repository.restoreNote(note.id);
      expect(await repository.getNotes(), hasLength(1));
      expect(await repository.getTrashedNotes(), isEmpty);
    });

    test('excluir definitivamente apaga do aparelho e da nuvem', () async {
      await repository.saveNote(title: 'Título', content: 'Texto');
      await settle();
      final note = (await repository.getNotes()).single;
      await repository.moveToTrash(note.id);

      await repository.deleteNotePermanently(note.id);
      await settle();

      expect(await repository.getTrashedNotes(), isEmpty);
      expect(cloud.notes, isEmpty);
    });

    test('esvaziar remove todas as notas da lixeira', () async {
      await repository.saveNote(title: 'A', content: 'Texto');
      await repository.saveNote(title: 'B', content: 'Texto');
      for (final note in await repository.getNotes()) {
        await repository.moveToTrash(note.id);
      }
      await settle();

      await repository.emptyTrash();
      await settle();

      expect(await repository.getTrashedNotes(), isEmpty);
      expect(cloud.notes, isEmpty);
    });
  });

  group('categorias', () {
    test('lista as padrão e as criadas pelo usuário', () async {
      await repository.createCategory('Faculdade');

      final names = (await repository.getCategories()).map((c) => c.name);

      expect(names, ['Estudos', 'Trabalho', 'Pessoal', 'Faculdade']);
    });

    test('filtra as notas por categoria', () async {
      await repository.saveNote(
        title: 'Prova',
        content: 'Texto',
        categoryId: 'estudos',
      );
      await repository.saveNote(title: 'Outra', content: 'Texto');

      final notes = await repository.getNotes(categoryId: 'estudos');

      expect(notes.single.title, 'Prova');
    });

    test('não aceita nome repetido', () async {
      await repository.createCategory('Faculdade');

      expect(
        repository.createCategory(' FACULDADE '),
        throwsA(isA<CategoryExistsException>()),
      );
      expect(
        repository.createCategory('estudos'),
        throwsA(isA<CategoryExistsException>()),
      );
    });
  });

  test('ao sair, as alterações pendentes ficam guardadas', () async {
    cloud.failure = RemoteErrorKind.offline;
    await repository.saveNote(title: 'Título', content: 'Texto');

    repository.stop();
    expect(() => repository.getNotes(), throwsStateError);

    cloud.failure = null;
    repository.start('ana');
    await settle();

    expect(cloud.notes, hasLength(1));
  });

  test('usuários diferentes não veem as notas um do outro', () async {
    await repository.saveNote(title: 'Da Ana', content: 'Texto');

    repository.stop();
    repository.start('bia');
    await settle();

    expect(await repository.getNotes(), isEmpty);
  });
}
