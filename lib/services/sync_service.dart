import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

// Responsável por toda a comunicação com o Firestore.
// Estrutura na nuvem: users/{uid}/notes/{syncId}
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;

  // Sem este limite, uma escrita offline pode ficar esperando para sempre.
  static const _timeout = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  // Gera um ID único sem precisar de internet.
  String newId(String uid) => _col(uid).doc().id;

  // Envia uma nota ao Firestore. Retorna true se deu certo.
  Future<bool> push(Note note) async {
    try {
      await _col(
        note.uid,
      ).doc(note.syncId).set(note.toFirestore()).timeout(_timeout);
      await _db.markSynced(note.syncId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Exclusão definitiva na nuvem.
  Future<bool> deleteRemote(String uid, String syncId) async {
    try {
      await _col(uid).doc(syncId).delete().timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Sincronização completa:
  // 1) envia as notas pendentes (criadas/editadas sem conexão);
  // 2) baixa as notas da nuvem e grava no SQLite quando a versão
  //    da nuvem é mais nova (vale a alteração mais recente).
  // Retorna null se deu certo, ou a mensagem de erro.
  Future<String?> syncAll(String uid) async {
    try {
      final pending = await _db.getUnsynced(uid);
      for (final note in pending) {
        final ok = await push(note);
        if (!ok) {
          return 'Sem conexão com o Firebase. As notas ficam salvas no '
              'aparelho e serão enviadas depois.';
        }
      }

      final snapshot = await _col(uid).get().timeout(_timeout);
      for (final doc in snapshot.docs) {
        final remote = Note.fromFirestore(doc.id, doc.data(), uid);
        final local = await _db.getBySyncId(uid, doc.id);

        if (local == null || remote.updatedAt.compareTo(local.updatedAt) > 0) {
          await _db.upsertFromRemote(remote);
        }
      }
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Sem permissão no Firestore. Confira as regras de segurança.';
      }
      return 'Erro do Firebase (${e.code}).';
    } catch (_) {
      return 'Não foi possível acessar o Firebase. Verifique a conexão.';
    }
  }
}
