import 'package:blocodenotasturmab/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final note = Note.create(
    uid: 'u1',
    title: 'Título',
    content: 'Conteúdo',
    category: 'Estudos',
    now: DateTime(2026, 11, 3, 9, 5),
  ).copyWith(trashed: true);

  test('toMap/fromMap preserva os dados (SQLite)', () {
    final copy = Note.fromMap(note.copyWith(id: 7).toMap());
    expect(copy.id, 7);
    expect(copy.remoteId, note.remoteId);
    expect(copy.category, 'Estudos');
    expect(copy.trashed, isTrue);
    expect(copy.updatedAt, note.updatedAt);
  });

  test('toFirestore não envia flags locais', () {
    final data = note.toFirestore();
    expect(data.keys, isNot(contains('synced')));
    expect(data.keys, isNot(contains('purged')));
    expect(data['uid'], 'u1');
  });

  test('fromFirestore volta como sincronizada', () {
    final copy = Note.fromFirestore(note.remoteId, note.toFirestore());
    expect(copy.synced, isTrue);
    expect(copy.title, 'Título');
    expect(copy.createdAt, note.createdAt);
  });

  test('formattedDate no padrão dd/MM/yyyy HH:mm', () {
    expect(note.formattedDate, '03/11/2026 09:05');
  });
}
