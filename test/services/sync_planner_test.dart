import 'package:blocodenotasturmab/models/syncable.dart';
import 'package:blocodenotasturmab/services/sync_planner.dart';
import 'package:flutter_test/flutter_test.dart';

class Item implements Syncable {
  @override
  final String id;
  @override
  final int updatedAt;
  @override
  final int? syncedAt;

  const Item(this.id, this.updatedAt, [this.syncedAt]);
}

void main() {
  SyncPlan<Item> plan(
    List<Item> local,
    List<Item> remote, {
    Set<String> deleting = const {},
  }) {
    return planSync<Item>(
      local: local,
      remote: remote,
      pendingDeletions: deleting,
    );
  }

  test('registro novo na nuvem é baixado', () {
    final result = plan([], [const Item('a', 10)]);

    expect(result.saveLocally.single.remote.id, 'a');
    expect(result.saveLocally.single.local, isNull);
  });

  test('registro novo no aparelho é enviado', () {
    final result = plan([const Item('a', 10)], []);

    expect(result.push.single.id, 'a');
    expect(result.deleteLocally, isEmpty);
  });

  test('registro igual nos dois lados não gera trabalho', () {
    final result = plan([const Item('a', 10, 10)], [const Item('a', 10)]);

    expect(result.saveLocally, isEmpty);
    expect(result.push, isEmpty);
    expect(result.markSynced, isEmpty);
  });

  test('alteração só na nuvem é baixada', () {
    final result = plan([const Item('a', 10, 10)], [const Item('a', 20)]);

    expect(result.saveLocally.single.remote.updatedAt, 20);
    expect(result.saveLocally.single.local!.updatedAt, 10);
  });

  test('alteração só no aparelho é enviada', () {
    final result = plan([const Item('a', 20, 10)], [const Item('a', 10)]);

    expect(result.push.single.id, 'a');
  });

  test('alteração local vence mesmo com relógio atrasado', () {
    // A nuvem não mudou desde a última sincronização, então não há conflito,
    // ainda que o horário local seja menor.
    final result = plan([const Item('a', 5, 10)], [const Item('a', 10)]);

    expect(result.push.single.id, 'a');
    expect(result.saveLocally, isEmpty);
  });

  test('conflito: a nuvem vence quando é mais recente', () {
    final result = plan([const Item('a', 20, 10)], [const Item('a', 30)]);

    expect(result.saveLocally.single.remote.updatedAt, 30);
    expect(result.push, isEmpty);
  });

  test('conflito: o aparelho vence quando é mais recente', () {
    final result = plan([const Item('a', 40, 10)], [const Item('a', 30)]);

    expect(result.push.single.updatedAt, 40);
    expect(result.saveLocally, isEmpty);
  });

  test('envio que chegou sem confirmação só é marcado como sincronizado', () {
    final result = plan([const Item('a', 20, 10)], [const Item('a', 20)]);

    expect(result.markSynced.single.id, 'a');
    expect(result.push, isEmpty);
  });

  test('registro apagado em outro aparelho sai daqui', () {
    final result = plan([const Item('a', 10, 10)], []);

    expect(result.deleteLocally.single.id, 'a');
  });

  test('edição local recria o registro apagado em outro aparelho', () {
    final result = plan([const Item('a', 20, 10)], []);

    expect(result.push.single.id, 'a');
    expect(result.deleteLocally, isEmpty);
  });

  test('exclusão pendente impede que o registro volte', () {
    final result = plan([], [const Item('a', 10)], deleting: {'a'});

    expect(result.saveLocally, isEmpty);
  });
}
