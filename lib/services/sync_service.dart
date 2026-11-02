import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../database/database_helper.dart';
import 'firestore_service.dart';

class PartialSyncException implements Exception {
  final int failedNotes;

  const PartialSyncException(this.failedNotes);
}

class SyncService {
  final DatabaseHelper database;
  final FirestoreService firestore;
  final Map<String, Future<void>> _running = {};

  SyncService({DatabaseHelper? database, FirestoreService? firestore})
    : database = database ?? DatabaseHelper.instance,
      firestore = firestore ?? FirestoreService();

  Future<void> synchronize(String uid) {
    return _running[uid] ??= _synchronize(uid).whenComplete(() {
      _running.remove(uid);
    });
  }

  Future<void> _synchronize(String uid) async {
    var failedNotes = 0;
    for (final note in await database.getPendingNotes(uid)) {
      try {
        final saved = await firestore
            .saveNote(note)
            .timeout(const Duration(seconds: 15));
        await database.applyRemote(saved, sentUpdatedAt: note.updatedAt);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' &&
            error.code != 'invalid-argument') {
          rethrow;
        }
        // Uma nota recusada não deve impedir o envio e a recuperação das demais.
        failedNotes++;
      }
    }
    final remoteNotes = await firestore
        .getNotes(uid)
        .timeout(const Duration(seconds: 15));
    for (final note in remoteNotes) {
      if (note.uid != uid) throw StateError('Nota de outro usuário.');
      await database.applyRemote(note);
    }
    if (failedNotes > 0) throw PartialSyncException(failedNotes);
  }

  static String errorMessage(Object error) {
    if (error is PartialSyncException) {
      return '${error.failedNotes} nota(s) não foram enviadas e continuam neste aparelho. '
          'Confira o conteúdo e as regras do Firestore antes de tentar novamente.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Sem permissão no Firebase. Confira as regras do Firestore.';
    }
    if (error is FirebaseException && error.code == 'unauthenticated') {
      return 'Entre novamente para sincronizar.';
    }
    return 'Não foi possível sincronizar. As alterações continuam neste aparelho. Tente novamente.';
  }
}
