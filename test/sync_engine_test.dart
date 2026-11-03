import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/services/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// SQLite e Firestore simulados em memória, com as mesmas regras de guarda
/// do DatabaseHelper.
class FakeAdapter implements SyncAdapter<Note> {
  final local = <String, Note>{};
  final remote = <String, Note>{};
  bool offline = false;

  void _checkConnection() {
    if (offline) throw Exception('sem conexão');
  }

  @override
  Future<List<Note>> localAll() async => local.values.toList();

  @override
  Future<void> applyRemote(Note item) async {
    final current = local[item.id];
    if (current != null &&
        current.syncStatus != SyncStatus.synced &&
        current.updatedAt > item.updatedAt) {
      return;
    }
    local[item.id] = item.copyWith(syncStatus: SyncStatus.synced);
  }

  @override
  Future<void> markSynced(String id, int updatedAt) async {
    final current = local[id];
    if (current != null &&
        current.updatedAt == updatedAt &&
        current.syncStatus == SyncStatus.pendingUpsert) {
      local[id] = current.copyWith(syncStatus: SyncStatus.synced);
    }
  }

  @override
  Future<void> localRemove(String id, SyncStatus onlyIf) async {
    if (local[id]?.syncStatus == onlyIf) local.remove(id);
  }

  @override
  Future<List<Note>> remoteAll() async {
    _checkConnection();
    return remote.values.toList();
  }

  @override
  Future<void> remoteUpsert(Note item) async {
    _checkConnection();
    remote[item.id] = item.copyWith(syncStatus: SyncStatus.synced);
  }

  @override
  Future<void> remoteDelete(String id) async {
    _checkConnection();
    remote.remove(id);
  }
}

Note note(
  String id, {
  int updatedAt = 100,
  String title = 'título',
  SyncStatus status = SyncStatus.pendingUpsert,
}) {
  return Note(
    id: id,
    uid: 'user-1',
    title: title,
    content: 'conteúdo',
    createdAt: 1,
    updatedAt: updatedAt,
    syncStatus: status,
  );
}

void main() {
  late FakeAdapter adapter;
  const engine = SyncEngine();

  Future<SyncReport> sync() async {
    final report = SyncReport();
    await engine.syncCollection(adapter, report);
    return report;
  }

  setUp(() => adapter = FakeAdapter());

  test('envia nota criada offline e marca como sincronizada', () async {
    adapter.local['a'] = note('a');

    final report = await sync();

    expect(report.pushed, 1);
    expect(adapter.remote.containsKey('a'), isTrue);
    expect(adapter.local['a']!.syncStatus, SyncStatus.synced);
  });

  test('baixa notas da nuvem em uma instalação nova', () async {
    adapter.remote['a'] = note('a', status: SyncStatus.synced);
    adapter.remote['b'] = note('b', status: SyncStatus.synced);

    final report = await sync();

    expect(report.pulled, 2);
    expect(adapter.local.keys, containsAll(['a', 'b']));
    expect(report.changedLocalData, isTrue);
  });

  test('exclusão pendente apaga na nuvem e depois localmente', () async {
    adapter.remote['a'] = note('a', status: SyncStatus.synced);
    adapter.local['a'] = note(
      'a',
      updatedAt: 200,
      status: SyncStatus.pendingDelete,
    );

    final report = await sync();

    expect(report.deletedRemotely, 1);
    expect(adapter.remote, isEmpty);
    expect(adapter.local, isEmpty);
  });

  test('nota excluída em outro aparelho sai do banco local', () async {
    adapter.local['a'] = note('a', status: SyncStatus.synced);

    final report = await sync();

    expect(report.removedLocally, 1);
    expect(adapter.local, isEmpty);
  });

  test('conflito: alteração local mais nova vence', () async {
    adapter.remote['a'] = note(
      'a',
      updatedAt: 100,
      title: 'nuvem',
      status: SyncStatus.synced,
    );
    adapter.local['a'] = note('a', updatedAt: 200, title: 'aparelho');

    await sync();

    expect(adapter.remote['a']!.title, 'aparelho');
    expect(adapter.local['a']!.syncStatus, SyncStatus.synced);
  });

  test('conflito: alteração remota mais nova vence', () async {
    adapter.remote['a'] = note(
      'a',
      updatedAt: 300,
      title: 'nuvem',
      status: SyncStatus.synced,
    );
    adapter.local['a'] = note('a', updatedAt: 200, title: 'aparelho');

    final report = await sync();

    expect(report.pushed, 0);
    expect(adapter.local['a']!.title, 'nuvem');
    expect(adapter.remote['a']!.title, 'nuvem');
  });

  test('sem conexão: nada se perde e tudo continua pendente', () async {
    adapter.local['a'] = note('a');
    adapter.offline = true;

    await expectLater(sync(), throwsException);
    expect(adapter.local['a']!.syncStatus, SyncStatus.pendingUpsert);

    adapter.offline = false;
    await sync();
    expect(adapter.remote.containsKey('a'), isTrue);
    expect(adapter.local['a']!.syncStatus, SyncStatus.synced);
  });
}
