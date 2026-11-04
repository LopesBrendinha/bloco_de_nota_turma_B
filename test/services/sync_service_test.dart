import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_category.dart';
import 'package:blocodenotasturmab/services/remote_data_source.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_remote_data_source.dart';
import '../support/test_database.dart';

const uid = 'ana';

Note note(String id, {String title = 'Título', int updatedAt = 100}) {
  return Note(
    id: id,
    uid: uid,
    title: title,
    content: 'Conteúdo',
    createdAt: 1,
    updatedAt: updatedAt,
  );
}

void main() {
  late FakeRemoteDataSource cloud;
  late DatabaseHelper phone;
  late SyncService phoneSync;

  /// Cria uma segunda instalação ligada à mesma nuvem.
  Future<(DatabaseHelper, SyncService)> newInstallation() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    return (database, SyncService(database, cloud));
  }

  setUp(() async {
    cloud = FakeRemoteDataSource();
    (phone, phoneSync) = await newInstallation();
  });

  group('envio', () {
    test('nota nova chega à nuvem e deixa de ser pendente', () async {
      await phone.insertNote(note('n1'));

      final result = await phoneSync.sync(uid);

      expect(result.failure, isNull);
      expect(cloud.notes['n1']!.title, 'Título');
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('edição chega à nuvem', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);

      await phone.updateNote(note('n1', title: 'Editada', updatedAt: 200));
      await phoneSync.sync(uid);

      expect(cloud.notes['n1']!.title, 'Editada');
    });

    test('exclusão definitiva apaga da nuvem', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);

      await phone.deleteNote(uid, 'n1');
      await phoneSync.sync(uid);

      expect(cloud.notes, isEmpty);
      expect(await phone.getPendingDeletions(uid), isEmpty);
    });

    test('nota na lixeira continua na nuvem e pode ser recuperada', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);

      final original = (await phone.getNote('n1'))!;
      await phone.updateNote(original.copyWith(trashedAt: 150, updatedAt: 150));
      await phoneSync.sync(uid);
      expect(cloud.notes['n1']!.isTrashed, isTrue);

      final trashed = (await phone.getNote('n1'))!;
      await phone.updateNote(trashed.copyWith(trashedAt: null, updatedAt: 160));
      await phoneSync.sync(uid);
      expect(cloud.notes['n1']!.isTrashed, isFalse);
    });
  });

  group('recuperação em outra instalação', () {
    test('uma instalação nova baixa notas e categorias', () async {
      await phone.insertNote(note('n1'));
      await phone.insertCategory(
        const NoteCategory(id: 'c1', uid: uid, name: 'Faculdade', updatedAt: 1),
      );
      await phoneSync.sync(uid);

      final (tablet, tabletSync) = await newInstallation();
      final result = await tabletSync.sync(uid);

      expect(result.changedLocally, isTrue);
      expect((await tablet.getNotes(uid)).single.id, 'n1');
      expect((await tablet.getCategories(uid)).single.name, 'Faculdade');
      expect(await tablet.countPendingChanges(uid), 0);
    });

    test('a pesquisa funciona nas notas baixadas', () async {
      await phone.insertNote(note('n1', title: 'Reunião'));
      await phoneSync.sync(uid);

      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      expect(await tablet.getNotes(uid, query: 'reuniao'), hasLength(1));
    });

    test('edição em um aparelho chega ao outro', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);
      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await tablet.updateNote(note('n1', title: 'Do tablet', updatedAt: 200));
      await tabletSync.sync(uid);
      await phoneSync.sync(uid);

      expect((await phone.getNote('n1'))!.title, 'Do tablet');
    });

    test('exclusão em um aparelho chega ao outro', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);
      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await tablet.deleteNote(uid, 'n1');
      await tabletSync.sync(uid);
      final result = await phoneSync.sync(uid);

      expect(result.changedLocally, isTrue);
      expect(await phone.getNote('n1'), isNull);
    });

    test('um usuário não recebe as notas de outro', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);

      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync('bia');

      expect(await tablet.getNotes('bia'), isEmpty);
      expect(await tablet.getNotes(uid), isEmpty);
    });
  });

  group('falhas de conexão', () {
    test('sem internet, a nota fica salva e pendente', () async {
      cloud.failure = RemoteErrorKind.offline;
      await phone.insertNote(note('n1'));

      final result = await phoneSync.sync(uid);

      expect(result.failure, RemoteErrorKind.offline);
      expect(await phone.getNote('n1'), isNotNull);
      expect(await phone.countPendingChanges(uid), 1);
    });

    test('quando a internet volta, as pendências são enviadas', () async {
      cloud.failure = RemoteErrorKind.offline;
      await phone.insertNote(note('n1'));
      await phone.insertNote(note('n2'));
      await phoneSync.sync(uid);

      cloud.failure = null;
      final result = await phoneSync.sync(uid);

      expect(result.failure, isNull);
      expect(cloud.notes.keys, unorderedEquals(['n1', 'n2']));
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('exclusão feita sem internet é enviada depois', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);

      cloud.failure = RemoteErrorKind.offline;
      await phone.deleteNote(uid, 'n1');
      await phoneSync.sync(uid);
      expect(cloud.notes, contains('n1'));

      cloud.failure = null;
      await phoneSync.sync(uid);

      expect(cloud.notes, isEmpty);
      expect(await phone.getNote('n1'), isNull);
    });

    test('queda no meio do envio mantém só o restante pendente', () async {
      await phone.insertNote(note('n1'));
      await phone.insertNote(note('n2'));
      await phone.insertNote(note('n3'));
      cloud.savesBeforeOffline = 1;

      final result = await phoneSync.sync(uid);

      expect(result.failure, RemoteErrorKind.offline);
      expect(cloud.notes, hasLength(1));
      expect(await phone.countPendingChanges(uid), 2);

      cloud.savesBeforeOffline = null;
      await phoneSync.sync(uid);

      expect(cloud.notes, hasLength(3));
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('para de enviar assim que a conexão cai', () async {
      // Cada tentativa sem internet esperaria o limite de tempo do envio.
      await phone.insertNote(note('n1'));
      await phone.insertNote(note('n2'));
      await phone.insertNote(note('n3'));
      cloud.savesBeforeOffline = 0;

      await phoneSync.sync(uid);

      expect(cloud.saveAttempts, 1);
    });
  });

  group('erros de permissão', () {
    test('o Firebase recusar a leitura não apaga nada', () async {
      await phone.insertNote(note('n1'));
      cloud.failure = RemoteErrorKind.permissionDenied;

      final result = await phoneSync.sync(uid);

      expect(result.failure, RemoteErrorKind.permissionDenied);
      expect(await phone.getNote('n1'), isNotNull);
    });

    test('uma nota recusada não impede o envio das outras', () async {
      await phone.insertNote(note('recusada'));
      await phone.insertNote(note('aceita'));
      cloud.rejectedNoteIds.add('recusada');

      final result = await phoneSync.sync(uid);

      expect(result.failure, RemoteErrorKind.permissionDenied);
      expect(cloud.notes.keys, ['aceita']);
      expect(await phone.countPendingChanges(uid), 1);
    });
  });

  group('conflitos', () {
    test('entre edições feitas sem internet, vence a mais recente', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);
      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await phone.updateNote(note('n1', title: 'Celular', updatedAt: 200));
      await tablet.updateNote(note('n1', title: 'Tablet', updatedAt: 300));

      await tabletSync.sync(uid);
      await phoneSync.sync(uid);
      await tabletSync.sync(uid);

      expect(cloud.notes['n1']!.title, 'Tablet');
      expect((await phone.getNote('n1'))!.title, 'Tablet');
      expect((await tablet.getNote('n1'))!.title, 'Tablet');
      expect(await phone.countPendingChanges(uid), 0);
      expect(await tablet.countPendingChanges(uid), 0);
    });

    test('a edição mais recente vence mesmo sincronizando primeiro', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);
      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await tablet.updateNote(note('n1', title: 'Tablet', updatedAt: 300));
      await phone.updateNote(note('n1', title: 'Celular', updatedAt: 200));

      await tabletSync.sync(uid);
      await phoneSync.sync(uid);

      expect(cloud.notes['n1']!.title, 'Tablet');
      expect((await phone.getNote('n1'))!.title, 'Tablet');
    });

    test('editar uma nota apagada em outro aparelho a recupera', () async {
      await phone.insertNote(note('n1'));
      await phoneSync.sync(uid);
      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await tablet.deleteNote(uid, 'n1');
      await tabletSync.sync(uid);
      await phone.updateNote(note('n1', title: 'Salva', updatedAt: 200));
      await phoneSync.sync(uid);

      expect(cloud.notes['n1']!.title, 'Salva');
    });
  });

  group('edições durante a sincronização', () {
    test('editar durante o envio mantém a edição pendente', () async {
      await phone.insertNote(note('n1'));
      cloud.onSaveNote = (sent) async {
        cloud.onSaveNote = null;
        await phone.updateNote(note('n1', title: 'Nova', updatedAt: 200));
      };

      await phoneSync.sync(uid);

      final edited = (await phone.getNote('n1'))!;
      expect(edited.title, 'Nova');
      expect(edited.syncedAt, 100);
      expect(await phone.countPendingChanges(uid), 1);

      await phoneSync.sync(uid);

      expect(cloud.notes['n1']!.title, 'Nova');
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('pedidos simultâneos fazem uma rodada de cada vez', () async {
      await phone.insertNote(note('n1'));

      final first = phoneSync.sync(uid);
      final second = phoneSync.sync(uid);
      await Future.wait([first, second]);

      expect(cloud.fetchCount, 2);
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('a troca de usuário espera a rodada anterior', () async {
      await phone.insertNote(note('n1'));
      await phone.insertNote(
        const Note(
          id: 'n2',
          uid: 'bia',
          title: 'Da Bia',
          content: 'Texto',
          createdAt: 1,
          updatedAt: 100,
        ),
      );

      final ana = phoneSync.sync(uid);
      final bia = phoneSync.sync('bia');
      await Future.wait([ana, bia]);

      expect(cloud.notes.keys, unorderedEquals(['n1', 'n2']));
    });
  });

  group('categorias', () {
    test('categoria nova chega à nuvem', () async {
      await phone.insertCategory(
        const NoteCategory(id: 'c1', uid: uid, name: 'Faculdade', updatedAt: 1),
      );

      await phoneSync.sync(uid);

      expect(cloud.categories['c1']!.name, 'Faculdade');
      expect(await phone.countPendingChanges(uid), 0);
    });

    test('excluir categoria propaga para o outro aparelho', () async {
      await phone.insertCategory(
        const NoteCategory(id: 'c1', uid: uid, name: 'Faculdade', updatedAt: 1),
      );
      final categorized = note('n1').copyWith(categoryId: 'c1');
      await phone.insertNote(categorized);
      await phoneSync.sync(uid);

      final (tablet, tabletSync) = await newInstallation();
      await tabletSync.sync(uid);

      await phone.deleteCategory(uid, 'c1');
      await phoneSync.sync(uid);
      await tabletSync.sync(uid);

      expect(cloud.categories, isEmpty);
      expect(await tablet.getCategories(uid), isEmpty);
      expect((await tablet.getNote('n1'))!.categoryId, isNull);
      expect(await tablet.countPendingChanges(uid), 0);
    });
  });
}
