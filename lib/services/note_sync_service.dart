import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

class NoteSyncService {
  final DatabaseHelper database = DatabaseHelper.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> synchronize(String uid) async {
    checkUser(uid);

    final collection = firestore.collection('users').doc(uid).collection('notes');
    final snapshot = await collection
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));

    checkUser(uid);

    final cloudNotes = snapshot.docs
        .map((document) => Note.fromCloud(document.id, document.data()))
        .toList();
    await database.mergeCloudNotes(uid, cloudNotes);

    final pendingNotes = await database.getPendingNotes(uid);

    for (final pendingNote in pendingNotes) {
      checkUser(uid);

      if (pendingNote.remoteId == null) {
        await database.assignRemoteId(
          pendingNote.id!,
          uid,
          collection.doc().id,
        );
      }

      final note = await database.getNote(pendingNote.id!, uid);
      if (note == null || !note.pendingSync) continue;

      checkUser(uid);

      await collection.doc(note.remoteId!).set({
        ...note.toCloudMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));

      await database.markSynced(note);
    }
  }

  void checkUser(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw StateError('Entre na sua conta para sincronizar as notas.');
    }
  }
}
