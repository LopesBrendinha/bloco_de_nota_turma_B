import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  final note = Note.create(
    uid: 'u1',
    title: 'Trabalho final',
    content: 'Entregar o PR',
    category: 'Estudos',
  );

  testWidgets('mostra título, categoria e indicador de pendência', (tester) async {
    await tester.pumpWidget(wrap(NoteCard(note: note)));

    expect(find.text('Trabalho final'), findsOneWidget);
    expect(find.text('Estudos'), findsOneWidget);
    expect(find.byKey(const Key('pending-sync')), findsOneWidget);
  });

  testWidgets('nota sincronizada não mostra o indicador', (tester) async {
    await tester.pumpWidget(wrap(NoteCard(note: note.copyWith(synced: true))));
    expect(find.byKey(const Key('pending-sync')), findsNothing);
  });

  testWidgets('botão de excluir chama onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(wrap(NoteCard(note: note, onDelete: () => deleted = true)));

    await tester.tap(find.byTooltip('Mover para a lixeira'));
    expect(deleted, isTrue);
  });
}
