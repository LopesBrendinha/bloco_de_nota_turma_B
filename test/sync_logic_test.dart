import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

Note _note({
  required int updatedAt,
  SyncStatus status = SyncStatus.synced,
  int? deletedAt,
}) {
  return Note(
    remoteId: 'abc',
    uid: 'user1',
    title: 'Título',
    content: 'Conteúdo',
    category: 'Estudos',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    deletedAt: deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(deletedAt),
    syncStatus: status,
  );
}

void main() {
  group('Note', () {
    test('converte para SQLite e volta sem perder dados', () {
      final note = _note(updatedAt: 2000, deletedAt: 3000);
      final copy = Note.fromMap(note.toMap());
      expect(copy.remoteId, note.remoteId);
      expect(copy.category, 'Estudos');
      expect(copy.updatedAt, note.updatedAt);
      expect(copy.deletedAt, note.deletedAt);
      expect(copy.syncStatus, SyncStatus.synced);
    });

    test('converte para Firestore sem os campos locais', () {
      final data = _note(updatedAt: 2000).toFirestore();
      expect(data.containsKey('id'), isFalse);
      expect(data.containsKey('sync_status'), isFalse);
      final copy = Note.fromFirestore('abc', data);
      expect(copy.title, 'Título');
      expect(copy.syncStatus, SyncStatus.synced);
    });

    test('gera um remoteId diferente para cada nota nova', () {
      final a = Note(
        uid: 'u',
        title: '',
        content: 'a',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final b = Note(
        uid: 'u',
        title: '',
        content: 'b',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(a.remoteId.length, 20);
      expect(a.remoteId, isNot(b.remoteId));
    });
  });

  group('resolveMerge', () {
    test('nota só na nuvem é baixada', () {
      expect(
        resolveMerge(local: null, remote: _note(updatedAt: 1)),
        MergeAction.takeRemote,
      );
    });

    test('nota sincronizada que sumiu da nuvem é apagada localmente', () {
      expect(
        resolveMerge(local: _note(updatedAt: 1), remote: null),
        MergeAction.deleteLocal,
      );
    });

    test('nota pendente que não está na nuvem é mantida', () {
      expect(
        resolveMerge(
          local: _note(updatedAt: 1, status: SyncStatus.pending),
          remote: null,
        ),
        MergeAction.keepLocal,
      );
    });

    test('nota sincronizada alterada em outro aparelho é atualizada', () {
      expect(
        resolveMerge(local: _note(updatedAt: 1), remote: _note(updatedAt: 5)),
        MergeAction.takeRemote,
      );
    });

    test('nota igual nos dois lados não muda', () {
      expect(
        resolveMerge(local: _note(updatedAt: 5), remote: _note(updatedAt: 5)),
        MergeAction.keepLocal,
      );
    });

    test('conflito: alteração local mais nova vence', () {
      expect(
        resolveMerge(
          local: _note(updatedAt: 9, status: SyncStatus.pending),
          remote: _note(updatedAt: 5),
        ),
        MergeAction.keepLocal,
      );
    });

    test('conflito: alteração da nuvem mais nova vence', () {
      expect(
        resolveMerge(
          local: _note(updatedAt: 3, status: SyncStatus.pending),
          remote: _note(updatedAt: 5),
        ),
        MergeAction.takeRemote,
      );
    });
  });
}
