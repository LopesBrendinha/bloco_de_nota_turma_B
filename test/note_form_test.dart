import 'dart:io';
import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/screens/note_form_page.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DelayedDatabase extends DatabaseHelper {
  final saveRequested = Completer<void>();
  final finishSave = Completer<void>();

  DelayedDatabase(String path) : super.forTesting(databaseFactoryFfi, path);

  @override
  Future<int> insertNote(Note note) async {
    saveRequested.complete();
    await finishSave.future;
    return super.insertNote(note);
  }
}

void main() {
  testWidgets('bloqueia edição dos campos durante uma gravação pendente', (
    tester,
  ) async {
    sqfliteFfiInit();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nota_salvando_'),
    ))!;
    final database = DelayedDatabase('${directory.path}/notes.db');
    await tester.runAsync(() async {
      await database.database;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFormPage(uid: 'ana', database: database),
        ),
      );
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Título salvo');
    await tester.enterText(find.byType(TextField).at(1), 'Conteúdo salvo');
    await tester.tap(find.byTooltip('Salvar nota'));
    await tester.pump();
    expect(database.saveRequested.isCompleted, isTrue);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.readOnly, isTrue);
    }
    await tester.runAsync(() async {
      database.finishSave.complete();
      for (var i = 0; i < 100; i++) {
        if ((await database.getNotes('ana')).isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect((await database.getNotes('ana')).single.content, 'Conteúdo salvo');
    });
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
  });

  testWidgets('formulário valida conteúdo e salva nota com categoria criada', (
    tester,
  ) async {
    sqfliteFfiInit();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('formulario_notas_'),
    ))!;
    final database = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      '${directory.path}/notes.db',
    );
    await tester.runAsync(() async {
      await database.database;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NoteFormPage(uid: 'ana', database: database),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salvar nota'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva o conteúdo da nota.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Prova de Flutter');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Revisar SQLite e Firebase',
    );
    await tester.tap(find.byTooltip('Nova categoria'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Faculdade');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Faculdade'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Salvar nota'));
      // Espera a operação real de SQLite terminar e a rota voltar.
      for (
        var i = 0;
        i < 100 && find.text('Nova nota').evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      final note = (await database.getNotes('ana')).single;
      expect(note.title, 'Prova de Flutter');
      expect(note.content, 'Revisar SQLite e Firebase');
      expect(note.category, 'Faculdade');
      expect(note.pendingSync, isTrue);
    });
    await tester.pumpAndSettle();
    expect(find.text('Nova nota'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
  });
}
