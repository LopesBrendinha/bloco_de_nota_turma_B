import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/repositories/note_repository.dart';
import 'package:blocodenotasturmab/services/note_remote_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Remoto que pode ser "desligado" para simular falta de conexão.
class ToggleRemote implements NoteRemoteDataSource {
  final NoteRemoteDataSource inner;
  bool online = true;
  ToggleRemote(this.inner);

  Future<T> _guard<T>(Future<T> Function() op) =>
      online ? op() : Future.error(Exception('offline'));

  @override
  Future<void> upsert(Note note) => _guard(() => inner.upsert(note));
  @override
  Future<void> delete(String uid, String remoteId) =>
      _guard(() => inner.delete(uid, remoteId));
  @override
  Future<List<Note>> fetchAll(String uid) => _guard(() => inner.fetchAll(uid));
}

const uid = 'user-a';

void main() {
  sqfliteFfiInit();

  late FakeFirebaseFirestore firestore;
  late ToggleRemote remote;
  late DatabaseHelper db;
  late NoteRepository repo;
  late DateTime now;

  DatabaseHelper newLocalDb() =>
      DatabaseHelper(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

  NoteRepository newRepo(DatabaseHelper local) =>
      NoteRepository(local: local, remote: remote, clock: () => now);

  Future<Map<String, dynamic>?> cloudDoc(Note n) async =>
      (await firestore.doc('users/${n.uid}/notes/${n.remoteId}').get()).data();

  Future<Note> create(String title, String content, {String category = 'Geral'}) async {
    await repo.save(Note.create(uid: uid, title: title, content: content, category: category));
    now = now.add(const Duration(minutes: 1));
    return (await repo.getNotes(uid)).firstWhere((n) => n.title == title);
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    remote = ToggleRemote(FirestoreNoteRemote(firestore: firestore));
    db = newLocalDb();
    now = DateTime(2026, 11, 1, 10);
    repo = newRepo(db);
  });

  tearDown(() => db.close());

  group('CRUD local + Firebase', () {
    test('criar salva no SQLite e no Firestore', () async {
      final note = await create('Prova', 'Estudar SQL', category: 'Estudos');

      expect(note.synced, isTrue);
      final doc = await cloudDoc(note);
      expect(doc?['title'], 'Prova');
      expect(doc?['category'], 'Estudos');
      expect(doc?['uid'], uid);
    });

    test('editar atualiza os dois armazenamentos', () async {
      final note = await create('Antigo', 'texto');
      await repo.save(note.copyWith(title: 'Novo'));

      expect((await repo.getNotes(uid)).single.title, 'Novo');
      expect((await cloudDoc(note))?['title'], 'Novo');
    });

    test('exclusão definitiva remove dos dois armazenamentos', () async {
      final note = await create('Apagar', 'x');
      await repo.deleteForever(note);

      expect(await db.getAllForSync(uid), isEmpty);
      expect(await cloudDoc(note), isNull);
    });
  });

  group('Categorias e pesquisa', () {
    setUp(() async {
      await create('Lista de compras', 'leite e pão', category: 'Pessoal');
      await create('Reunião', 'pauta do projeto', category: 'Trabalho');
      await create('Flutter', 'estudar widgets e projeto', category: 'Estudos');
    });

    test('pesquisa pelo título', () async {
      final r = await repo.getNotes(uid, query: 'reuni');
      expect(r.map((n) => n.title), ['Reunião']);
    });

    test('pesquisa pelo conteúdo', () async {
      final r = await repo.getNotes(uid, query: 'projeto');
      expect(r.map((n) => n.title), unorderedEquals(['Reunião', 'Flutter']));
    });

    test('filtro de categoria combinado com pesquisa', () async {
      final r = await repo.getNotes(uid, query: 'projeto', category: 'Estudos');
      expect(r.map((n) => n.title), ['Flutter']);
    });

    test('categorias incluem padrões e as criadas pelo usuário', () async {
      await create('Receita', 'bolo', category: 'Culinária');
      expect(await repo.getCategories(uid), containsAll(['Geral', 'Estudos', 'Culinária']));
    });

    test('ordenadas pela última atualização', () async {
      final titles = (await repo.getNotes(uid)).map((n) => n.title);
      expect(titles, ['Flutter', 'Reunião', 'Lista de compras']);
    });
  });

  group('Lixeira', () {
    test('mover para a lixeira oculta da lista e pode ser restaurada', () async {
      final note = await create('Temp', 'x');
      await repo.moveToTrash(note);

      expect(await repo.getNotes(uid), isEmpty);
      expect((await repo.getTrash(uid)).single.title, 'Temp');
      expect((await cloudDoc(note))?['trashed'], isTrue);

      await repo.restore((await repo.getTrash(uid)).single);
      expect((await repo.getNotes(uid)).single.title, 'Temp');
      expect(await repo.getTrash(uid), isEmpty);
    });

    test('esvaziar lixeira apaga só as notas da lixeira', () async {
      final a = await create('A', 'x');
      await create('B', 'y');
      await repo.moveToTrash(a);
      await repo.emptyTrash(uid);

      expect((await repo.getNotes(uid)).single.title, 'B');
      expect(await cloudDoc(a), isNull);
    });
  });

  group('Sincronização e erros de conexão', () {
    test('sem conexão a nota fica salva localmente como pendente', () async {
      remote.online = false;
      final ok = await repo.save(Note.create(uid: uid, title: 'Offline', content: 'x'));

      expect(ok, isFalse);
      final note = (await repo.getNotes(uid)).single;
      expect(note.synced, isFalse);
      expect(await cloudDoc(note), isNull);
    });

    test('sync envia pendências quando a conexão volta', () async {
      remote.online = false;
      await repo.save(Note.create(uid: uid, title: 'Offline', content: 'x'));
      expect(await repo.sync(uid), isFalse);

      remote.online = true;
      expect(await repo.sync(uid), isTrue);
      final note = (await repo.getNotes(uid)).single;
      expect(note.synced, isTrue);
      expect((await cloudDoc(note))?['title'], 'Offline');
    });

    test('exclusão offline é concluída na nuvem no próximo sync', () async {
      final note = await create('Some', 'x');
      remote.online = false;
      await repo.deleteForever(note);

      expect(await repo.getNotes(uid), isEmpty);
      expect(await cloudDoc(note), isNotNull);

      remote.online = true;
      await repo.sync(uid);
      expect(await cloudDoc(note), isNull);
      expect(await db.getAllForSync(uid), isEmpty);
    });

    test('outra instalação recupera as notas da nuvem', () async {
      await create('Nota 1', 'a');
      await create('Nota 2', 'b');

      final otherDb = newLocalDb();
      final otherRepo = newRepo(otherDb);
      expect(await otherRepo.getNotes(uid), isEmpty);

      expect(await otherRepo.sync(uid), isTrue);
      expect((await otherRepo.getNotes(uid)).map((n) => n.title),
          unorderedEquals(['Nota 1', 'Nota 2']));
      await otherDb.close();
    });

    test('alteração mais recente feita em outra instalação vence', () async {
      final note = await create('Original', 'a');
      final otherDb = newLocalDb();
      final otherRepo = newRepo(otherDb);
      await otherRepo.sync(uid);

      final copy = (await otherRepo.getNotes(uid)).single;
      await otherRepo.save(copy.copyWith(title: 'Editada no outro aparelho'));

      await repo.sync(uid);
      expect((await repo.getNotes(uid)).single.title, 'Editada no outro aparelho');
      expect((await repo.getNotes(uid)).single.id, note.id);
      await otherDb.close();
    });

    test('nota excluída em outra instalação some no sync', () async {
      await create('Compartilhada', 'a');
      final otherDb = newLocalDb();
      final otherRepo = newRepo(otherDb);
      await otherRepo.sync(uid);
      await otherRepo.deleteForever((await otherRepo.getNotes(uid)).single);

      await repo.sync(uid);
      expect(await repo.getNotes(uid), isEmpty);
      await otherDb.close();
    });
  });

  test('um usuário não enxerga as notas de outro', () async {
    await create('Minha', 'segredo');
    await firestore.doc('users/user-b/notes/x').set(
          Note.create(uid: 'user-b', title: 'Dele', content: 'y').toFirestore(),
        );

    await repo.sync('user-b');
    expect((await repo.getNotes(uid)).map((n) => n.title), ['Minha']);
    expect((await repo.getNotes('user-b')).map((n) => n.title), ['Dele']);
  });
}
