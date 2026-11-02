import 'dart:async';
import 'dart:io';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/screens/notes_page.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DelayedFirestore extends FirestoreService {
  final firstWrite = Completer<void>();
  final started = Completer<void>();
  final Map<String, Note> notes = {};

  @override
  Future<Note> saveNote(Note note) async {
    if (!started.isCompleted) {
      started.complete();
      await firstWrite.future;
    }
    final saved = Note.fromFirestore(note.remoteId, note.toFirestore());
    notes[note.remoteId] = saved;
    return saved;
  }

  @override
  Future<List<Note>> getNotes(String uid) async => notes.values.toList();
}

void main() {
  testWidgets('repete a sincronização solicitada durante outro envio', (
    tester,
  ) async {
    sqfliteFfiInit();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('notas_tela_'),
    ))!;
    final database = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      '${directory.path}/notes.db',
    );
    final remote = DelayedFirestore();
    const first = Note(
      remoteId: 'primeira',
      uid: 'ana',
      title: 'Primeira',
      content: 'Teste',
      createdAt: 100,
      updatedAt: 100,
    );
    const second = Note(
      remoteId: 'segunda',
      uid: 'ana',
      title: 'Segunda',
      content: 'Teste',
      createdAt: 200,
      updatedAt: 200,
    );
    await tester.runAsync(() async {
      await database.insertNote(first);
      await tester.pumpWidget(
        MaterialApp(
          home: NotesPage(
            uid: 'ana',
            database: database,
            syncService: SyncService(database: database, firestore: remote),
          ),
        ),
      );
      for (var i = 0; i < 100 && !remote.started.isCompleted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      expect(remote.started.isCompleted, isTrue);
      await database.insertNote(second);
      final dynamic page = tester.state(find.byType(NotesPage));
      await page.refresh();
      remote.firstWrite.complete();
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (remote.notes.length == 2 &&
            find.text('Notas sincronizadas.').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(remote.notes.keys, containsAll(['primeira', 'segunda']));
      expect(await database.getPendingNotes('ana'), isEmpty);
    });
    expect(find.text('Segunda'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
  });
}
