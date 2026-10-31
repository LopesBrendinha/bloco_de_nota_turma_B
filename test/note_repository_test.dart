import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/repositories/note_repository.dart';
import 'package:blocodenotasturmab/repositories/sync_outcome.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testes da integração entre o SQLite e o Cloud Firestore.
///
/// O banco local roda em memória (`sqflite_common_ffi`) e o Firestore é
/// substituído pelo `fake_cloud_firestore`, então a sincronização é testada
/// de verdade — não apenas compilada.
void main() {
  const uid = 'usuario-de-teste';

  late FakeFirebaseFirestore firestore;
  late NoteRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTests();

    firestore = FakeFirebaseFirestore();
    repository = NoteRepository(
      cloud: FirestoreService(firestore: firestore),
    );
  });

  tearDown(() => DatabaseHelper.instance.resetForTests());

  /// Documentos existentes em users/{uid}/notes.
  Future<List<Map<String, dynamic>>> remoteNotes() async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('notes')
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  group('CRUD e integração com o Firebase', () {
    test('salvar uma nota grava no SQLite e no Firestore', () async {
      final outcome = await repository.saveNote(
        uid: uid,
        title: 'Prova de BD',
        content: 'Estudar normalização',
      );

      expect(outcome.isSynced, isTrue);

      final local = await repository.getNotes(uid: uid);
      expect(local, hasLength(1));
      expect(local.first.title, 'Prova de BD');
      expect(local.first.syncStatus, SyncStatus.synced);

      final remote = await remoteNotes();
      expect(remote, hasLength(1));
      expect(remote.first['title'], 'Prova de BD');
      expect(remote.first['uid'], uid);
    });

    test('editar uma nota atualiza os dois armazenamentos', () async {
      await repository.saveNote(uid: uid, title: 'Rascunho', content: 'a');

      final saved = (await repository.getNotes(uid: uid)).first;

      await repository.saveNote(
        uid: uid,
        title: 'Versão final',
        content: 'b',
        existing: saved,
      );

      final local = await repository.getNotes(uid: uid);
      expect(local, hasLength(1), reason: 'o UUID deve ser reaproveitado');
      expect(local.first.title, 'Versão final');

      final remote = await remoteNotes();
      expect(remote, hasLength(1));
      expect(remote.first['title'], 'Versão final');
    });

    test('nova instalação recupera as notas da nuvem', () async {
      await repository.saveNote(uid: uid, title: 'Nota antiga', content: 'x');

      // Simula outro aparelho: banco local zerado, mesma conta na nuvem.
      await DatabaseHelper.instance.resetForTests();

      expect(await repository.getNotes(uid: uid), isEmpty);

      final outcome = await repository.synchronize(uid);

      expect(outcome.isSynced, isTrue);
      expect(outcome.pulled, 1);

      final recovered = await repository.getNotes(uid: uid);
      expect(recovered, hasLength(1));
      expect(recovered.first.title, 'Nota antiga');
    });

    test('as notas de um usuário não aparecem para outro', () async {
      await repository.saveNote(uid: uid, title: 'Minha nota', content: 'x');
      await repository.saveNote(
        uid: 'outro-usuario',
        title: 'Nota alheia',
        content: 'y',
      );

      final mine = await repository.getNotes(uid: uid);

      expect(mine, hasLength(1));
      expect(mine.first.title, 'Minha nota');
    });
  });

  group('Categorias e pesquisa', () {
    test('a nota guarda a categoria escolhida', () async {
      await repository.saveCategory(
        uid: uid,
        name: 'Estudos',
        colorValue: 0xFF6C4AB6,
      );

      final category = (await repository.getCategories(uid)).single;

      await repository.saveNote(
        uid: uid,
        title: 'Trabalho de POO',
        content: 'Entregar sexta',
        categoryId: category.id,
      );

      final filtered = await repository.getNotes(
        uid: uid,
        categoryId: category.id,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.categoryId, category.id);

      final counts = await repository.countNotesByCategory(uid);
      expect(counts[category.id], 1);
    });

    test('excluir a categoria mantém as notas, sem categoria', () async {
      await repository.saveCategory(
        uid: uid,
        name: 'Temporária',
        colorValue: 0xFF2F9E7E,
      );

      final category = (await repository.getCategories(uid)).single;

      await repository.saveNote(
        uid: uid,
        title: 'Nota com categoria',
        content: 'x',
        categoryId: category.id,
      );

      await repository.deleteCategory(category);

      expect(await repository.getCategories(uid), isEmpty);

      final notes = await repository.getNotes(uid: uid);
      expect(notes, hasLength(1));
      expect(notes.first.categoryId, isNull);
    });

    test('a pesquisa encontra pelo título e pelo conteúdo', () async {
      await repository.saveNote(
        uid: uid,
        title: 'Lista de compras',
        content: 'arroz e feijão',
      );
      await repository.saveNote(
        uid: uid,
        title: 'Reunião',
        content: 'falar sobre o arroz do refeitório',
      );
      await repository.saveNote(
        uid: uid,
        title: 'Aniversário',
        content: 'comprar bolo',
      );

      final byTitle = await repository.getNotes(uid: uid, query: 'compras');
      expect(byTitle, hasLength(1));
      expect(byTitle.first.title, 'Lista de compras');

      final byContent = await repository.getNotes(uid: uid, query: 'arroz');
      expect(byContent, hasLength(2));

      // A pesquisa ignora maiúsculas e acentos (coluna search_text).
      final caseInsensitive =
          await repository.getNotes(uid: uid, query: 'ANIVERSÁRIO');
      expect(caseInsensitive, hasLength(1));

      final withoutAccent =
          await repository.getNotes(uid: uid, query: 'aniversario');
      expect(withoutAccent, hasLength(1));

      final noMatch = await repository.getNotes(uid: uid, query: 'xyz');
      expect(noMatch, isEmpty);
    });

    test('a ordenação por data funciona nos dois sentidos', () async {
      await repository.saveNote(uid: uid, title: 'Primeira', content: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.saveNote(uid: uid, title: 'Segunda', content: 'b');

      final recentFirst = await repository.getNotes(
        uid: uid,
        sort: NoteSort.createdDesc,
      );
      expect(recentFirst.first.title, 'Segunda');

      final oldestFirst = await repository.getNotes(
        uid: uid,
        sort: NoteSort.createdAsc,
      );
      expect(oldestFirst.first.title, 'Primeira');
    });
  });

  group('Lixeira com recuperação', () {
    test('a nota some da lista, vai para a lixeira e volta', () async {
      await repository.saveNote(uid: uid, title: 'Descartável', content: 'x');

      final note = (await repository.getNotes(uid: uid)).single;

      await repository.moveToTrash(note);

      expect(await repository.getNotes(uid: uid), isEmpty);
      expect(await repository.getTrashedNotes(uid: uid), hasLength(1));

      // A lixeira é um campo sincronizado, não a ausência do documento.
      final remote = await remoteNotes();
      expect(remote, hasLength(1));
      expect(remote.first['isDeleted'], isTrue);

      final trashed = (await repository.getTrashedNotes(uid: uid)).single;
      await repository.restoreFromTrash(trashed);

      expect(await repository.getNotes(uid: uid), hasLength(1));
      expect(await repository.getTrashedNotes(uid: uid), isEmpty);
    });

    test('excluir definitivamente apaga local e nuvem', () async {
      await repository.saveNote(uid: uid, title: 'Adeus', content: 'x');

      final note = (await repository.getNotes(uid: uid)).single;
      await repository.moveToTrash(note);

      final trashed = (await repository.getTrashedNotes(uid: uid)).single;
      await repository.deleteForever(trashed);

      expect(await repository.getTrashedNotes(uid: uid), isEmpty);
      expect(await remoteNotes(), isEmpty);
    });
  });

  group('Tratamento de falhas de conexão', () {
    test('uma operação que nunca responde vira falha de conexão', () async {
      // O SDK do Firestore não lança erro quando não alcança o servidor:
      // ele retenta para sempre e o Future nunca completa. Sem o timeout
      // do FirestoreService, a tela travaria em silêncio.
      final service = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        timeout: const Duration(milliseconds: 50),
      );

      final nuncaCompleta = Completer<void>().future;

      await expectLater(
        service.guard(() => nuncaCompleta, 'falhou'),
        throwsA(
          isA<CloudException>()
              .having((error) => error.isOffline, 'isOffline', isTrue)
              .having((error) => error.code, 'code', 'timeout'),
        ),
      );
    });

    test('sem internet a nota é salva localmente e fica pendente', () async {
      final offline = NoteRepository(cloud: _OfflineFirestoreService());

      final outcome = await offline.saveNote(
        uid: uid,
        title: 'Escrita offline',
        content: 'x',
      );

      expect(outcome.state, SyncState.offline);
      expect(outcome.message, isNotNull);

      final local = await offline.getNotes(uid: uid);
      expect(local, hasLength(1), reason: 'a gravação local não pode falhar');
      expect(local.first.syncStatus, SyncStatus.pendingUpsert);

      expect(await remoteNotes(), isEmpty);
    });

    test('a fila pendente sobe quando a conexão volta', () async {
      final offline = NoteRepository(cloud: _OfflineFirestoreService());

      await offline.saveNote(uid: uid, title: 'Escrita offline', content: 'x');
      expect(await repository.countPendingNotes(uid), 1);

      // `repository` usa o Firestore falso que funciona: a conexão voltou.
      final outcome = await repository.synchronize(uid);

      expect(outcome.isSynced, isTrue);
      expect(outcome.pushed, 1);
      expect(await repository.countPendingNotes(uid), 0);

      final remote = await remoteNotes();
      expect(remote, hasLength(1));
      expect(remote.first['title'], 'Escrita offline');
    });
  });
}

/// Firestore que falha como se não houvesse internet.
class _OfflineFirestoreService extends FirestoreService {
  _OfflineFirestoreService() : super(firestore: FakeFirebaseFirestore());

  CloudException get _offline => CloudException(
        'Sem conexão com o Firebase.',
        isOffline: true,
        code: 'unavailable',
      );

  @override
  Future<void> upsertNote(_) async => throw _offline;

  @override
  Future<void> upsertCategory(_) async => throw _offline;

  @override
  Future<void> deleteNote({required String uid, required String id}) async =>
      throw _offline;

  @override
  Future<void> deleteCategory({
    required String uid,
    required String id,
  }) async =>
      throw _offline;
}
