import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';
import 'package:blocodenotasturmab/main.dart' as app;
import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:blocodenotasturmab/widgets/note_card.dart';
import 'package:blocodenotasturmab/models/note.dart';

class ControlledCloud implements NotesCloud {
  final service = FirestoreService();
  bool offline = false;

  void checkConnection() {
    if (offline) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
  }

  @override
  Future<Note> send(Note note) {
    checkConnection();
    return service.send(note);
  }

  @override
  Future<List<Note>> fetch(String uid) {
    checkConnection();
    return service.fetch(uid);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cadastro, categorias, pesquisa, arquivo e sincronização entre instalações',
    (tester) async {
      const cloudEvidence = bool.fromEnvironment('CLOUD_EVIDENCE');
      if (!DefaultFirebaseOptions.useEmulators && !cloudEvidence) {
        fail(
          'Use os emuladores ou autorize a validação na nuvem com CLOUD_EVIDENCE=true.',
        );
      }
      final prefix = cloudEvidence ? 'nuvem' : 'emulador';
      await app.main();
      final cloud = ControlledCloud();
      runApp(app.MyApp(notesCloud: cloud));
      await tester.pumpAndSettle();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-login');

      await tester.ensureVisible(
        find.text('Ainda não possui uma conta? Cadastre-se'),
      );
      await tester.tap(find.text('Ainda não possui uma conta? Cadastre-se'));
      await tester.pumpAndSettle();
      final email =
          'validacao.${DateTime.now().millisecondsSinceEpoch}@example.com';
      final password = const Uuid().v4();
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.enterText(find.byType(TextField).at(2), password);
      await tester.ensureVisible(find.text('Criar minha conta'));
      await tester.tap(find.text('Criar minha conta'));
      await waitFor(
        tester,
        () => find.text('Minhas notas').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Nova nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Salvar nota'));
      await waitFor(
        tester,
        () => find.text('Escreva o conteúdo da nota.').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Nova categoria'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Faculdade');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'Revisão de banco de dados',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Estudar SQLite e Firestore.\nSeparar os exercícios da próxima aula.',
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-editor');
      await tester.tap(find.byTooltip('Salvar nota'));
      await waitFor(tester, () => find.byType(NoteCard).evaluate().isNotEmpty);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final database = DatabaseHelper.instance;
      await waitFor(
        tester,
        () async => (await database.pendingNotes(uid)).isEmpty,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-notas');

      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes');
      final remote = await reference.get(
        const GetOptions(source: Source.server),
      );
      expect(remote.docs.single.data()['category'], 'Faculdade');
      expect(remote.docs.single.data()['content'], contains('SQLite'));

      await tester.enterText(find.byType(TextField), 'EXERCICIOS');
      await tester.pumpAndSettle();
      expect(find.byType(NoteCard), findsOneWidget);
      await binding.takeScreenshot('$prefix-pesquisa');
      await tester.enterText(find.byType(TextField), 'não existe');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma nota encontrada.'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar pesquisa'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opções da nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivadas'));
      await waitFor(tester, () => find.byType(NoteCard).evaluate().isNotEmpty);
      await waitFor(
        tester,
        () async => (await database.pendingNotes(uid)).isEmpty,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-arquivo');
      expect(
        (await reference.get(
          const GetOptions(source: Source.server),
        )).docs.single.data()['archived'],
        true,
      );

      final secondDatabase = DatabaseHelper(
        fileName: 'segunda-instalacao-${const Uuid().v4()}.db',
      );
      final secondSync = SyncService(
        database: secondDatabase,
        cloud: FirestoreService(),
        uid: uid,
        sessionIsActive: () => FirebaseAuth.instance.currentUser?.uid == uid,
      );
      try {
        await secondSync.sync();
        expect(secondSync.error, isNull);
        final recovered = (await secondDatabase.getNotes(
          uid,
          archived: true,
        )).single;
        expect(recovered.title, 'Revisão de banco de dados');
        expect(recovered.category, 'Faculdade');
      } finally {
        secondSync.dispose();
        await secondDatabase.close();
      }

      await tester.tap(find.byTooltip('Opções da nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desarquivar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas').first);
      await waitFor(tester, () => find.byType(NoteCard).evaluate().isNotEmpty);
      await tester.tap(find.byType(NoteCard));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Revisão concluída');
      cloud.offline = true;
      await tester.enterText(
        find.byType(TextField).at(1),
        'Estudar SQLite e Firestore.\nTexto atualizado sem conexão.',
      );
      await tester.tap(find.byTooltip('Salvar nota'));
      await waitFor(
        tester,
        () => find.text('Revisão concluída').evaluate().isNotEmpty,
      );
      expect(
        (await database.pendingNotes(uid)).single.content,
        contains('sem conexão'),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-pendente');
      cloud.offline = false;
      final syncButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Sincronizar agora',
      );
      await waitFor(
        tester,
        () => tester.widget<IconButton>(syncButton).onPressed != null,
      );
      await tester.tap(find.byTooltip('Sincronizar agora'));
      await waitFor(
        tester,
        () async => (await database.pendingNotes(uid)).isEmpty,
      );
      expect(
        (await reference.get(
          const GetOptions(source: Source.server),
        )).docs.single.data()['title'],
        'Revisão concluída',
      );
      expect(
        (await reference.get(
          const GetOptions(source: Source.server),
        )).docs.single.data()['content'],
        contains('sem conexão'),
      );

      await tester.tap(find.byTooltip('Sair'));
      await waitFor(tester, () => find.text('Entrar').evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await waitFor(
        tester,
        () => find.text('Revisão concluída').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Nova nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Nota temporária');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Conferir a exclusão nos dois bancos.',
      );
      await tester.tap(find.byTooltip('Salvar nota'));
      await waitFor(
        tester,
        () => find.text('Nota temporária').evaluate().isNotEmpty,
      );
      await waitFor(
        tester,
        () async => (await database.pendingNotes(uid)).isEmpty,
      );
      final temporaryCard = find.ancestor(
        of: find.text('Nota temporária'),
        matching: find.byType(NoteCard),
      );
      await tester.tap(
        find.descendant(
          of: temporaryCard,
          matching: find.byTooltip('Opções da nota'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await waitFor(
        tester,
        () => find.text('Nota temporária').evaluate().isEmpty,
      );
      await waitFor(
        tester,
        () async => (await database.pendingNotes(uid)).isEmpty,
      );
      final deleted = (await reference.get(
        const GetOptions(source: Source.server),
      )).docs.singleWhere((doc) => doc.data()['deleted'] == true).data();
      expect(deleted['deleted'], true);
      expect(deleted['content'], isEmpty);
      final active = (await reference.get(
        const GetOptions(source: Source.server),
      )).docs.singleWhere((doc) => doc.data()['deleted'] == false);
      final otherApp = await Firebase.initializeApp(
        name: 'outra-conta',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final otherAuth = FirebaseAuth.instanceFor(app: otherApp);
      final otherDb = FirebaseFirestore.instanceFor(app: otherApp);
      otherDb.settings = const Settings(persistenceEnabled: false);
      if (DefaultFirebaseOptions.useEmulators) {
        await otherAuth.useAuthEmulator(
          DefaultFirebaseOptions.emulatorHost,
          9099,
        );
        otherDb.useFirestoreEmulator(DefaultFirebaseOptions.emulatorHost, 8080);
      }
      try {
        final foreign = otherDb.doc('users/$uid/notes/${active.id}');
        final denied = isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        );
        await expectLater(
          foreign.get(const GetOptions(source: Source.server)),
          throwsA(denied),
        );
        await otherAuth.createUserWithEmailAndPassword(
          email: 'outra.${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: const Uuid().v4(),
        );
        await expectLater(
          foreign.get(const GetOptions(source: Source.server)),
          throwsA(denied),
        );
        await expectLater(
          foreign.update({'title': 'Alterada por outra conta'}),
          throwsA(denied),
        );
      } finally {
        await otherAuth.signOut();
        await otherApp.delete();
      }
      binding.reportData?.addAll({
        'projectId': DefaultFirebaseOptions.currentPlatform.projectId,
        'uid': uid,
        'noteId': active.id,
        'cloud': cloudEvidence,
      });
      await tester.pumpAndSettle();
      await binding.takeScreenshot('$prefix-final');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> waitFor(
  WidgetTester tester,
  FutureOr<bool> Function() ready,
) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (await ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('A operação não terminou dentro de 30 segundos.');
}
