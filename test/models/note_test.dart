import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_category.dart';
import 'package:blocodenotasturmab/models/syncable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const note = Note(
    id: 'n1',
    uid: 'ana',
    title: 'Título',
    content: 'Conteúdo',
    categoryId: 'estudos',
    createdAt: 10,
    updatedAt: 20,
    trashedAt: 30,
    syncedAt: 20,
  );

  test('preserva os campos na ida e volta do SQLite', () {
    final copy = Note.fromMap(note.toMap());

    expect(copy.toMap(), note.toMap());
    expect(note.toMap()['search_text'], 'titulo\nconteudo');
  });

  test('preserva os campos na ida e volta do Firestore', () {
    final copy = Note.fromRemoteMap('n1', note.toRemoteMap());

    expect(copy.toRemoteMap(), note.toRemoteMap());
  });

  test('o estado local de sincronização não vai para a nuvem', () {
    final map = note.toRemoteMap();

    expect(map.containsKey('syncedAt'), isFalse);
    expect(map.containsKey('search_text'), isFalse);
  });

  test('copyWith diferencia "manter" de "limpar"', () {
    expect(note.copyWith(title: 'Outro').categoryId, 'estudos');
    expect(note.copyWith(categoryId: null).categoryId, isNull);
    expect(note.copyWith(trashedAt: null).isTrashed, isFalse);
  });

  test('hasPendingChanges compara updatedAt com syncedAt', () {
    expect(note.hasPendingChanges, isFalse);
    expect(note.copyWith(updatedAt: 21).hasPendingChanges, isTrue);
    expect(note.copyWith(syncedAt: null).hasPendingChanges, isTrue);
  });

  test('categoria preserva os campos e reconhece as padrão', () {
    const category = NoteCategory(
      id: 'c1',
      uid: 'ana',
      name: 'Faculdade',
      updatedAt: 5,
    );

    expect(NoteCategory.fromMap(category.toMap()).name, 'Faculdade');
    expect(
      NoteCategory.fromRemoteMap('c1', category.toRemoteMap()).updatedAt,
      5,
    );
    expect(category.isDefault, isFalse);
    expect(NoteCategory.defaults.first.isDefault, isTrue);
  });
}
