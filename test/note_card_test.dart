import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cartão exibe categoria e chama arquivar e excluir', (
    tester,
  ) async {
    int archives = 0;
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: const Note(
              remoteId: '1',
              uid: 'ana',
              title: 'Prova',
              content: 'Estudar',
              category: 'Estudos',
              createdAt: 100,
              updatedAt: 100,
            ),
            onTap: () {},
            onArchive: () => archives++,
            onDelete: () => deletes++,
          ),
        ),
      ),
    );
    expect(find.textContaining('Estudos'), findsOneWidget);
    await tester.tap(find.byTooltip('Opções da nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();
    expect(archives, 1);
    await tester.tap(find.byTooltip('Opções da nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
  });
}
