import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import 'firestore_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseHelper database;
  final NotesCloud cloud;
  final String uid;
  final bool Function() sessionIsActive;
  bool syncing = false;
  bool _disposed = false;
  String? error;
  int pending = 0;
  Timer? _timer;

  SyncService({
    required this.database,
    required this.cloud,
    required this.uid,
    required this.sessionIsActive,
  });

  void start() {
    unawaited(sync());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }

  Future<void> sync() async {
    if (syncing || _disposed || !sessionIsActive()) return;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      final notes = await database.pendingNotes(uid);
      for (final note in notes) {
        if (_disposed || !sessionIsActive()) return;
        final saved = await cloud
            .send(note)
            .timeout(const Duration(seconds: 12));
        if (_disposed || !sessionIsActive()) return;
        if (saved.uid != uid || saved.cloudId != note.cloudId) {
          throw StateError('Resposta de sincronização inválida.');
        }
        await database.acceptRemote(saved, expectedChange: note.changeId);
      }
      if (_disposed || !sessionIsActive()) return;
      final remote = await cloud
          .fetch(uid)
          .timeout(const Duration(seconds: 12));
      for (final note in remote) {
        if (_disposed || !sessionIsActive()) return;
        if (note.uid != uid) throw StateError('Nota de outro usuário.');
        await database.acceptRemote(note);
      }
    } on FirebaseException catch (e) {
      error = e.code == 'permission-denied'
          ? 'Acesso negado. Confira as regras do Firestore.'
          : 'Não foi possível acessar o Firebase. Suas alterações ficam neste aparelho.';
    } on TimeoutException {
      error = 'Sem resposta do Firebase. Tentaremos novamente em instantes.';
    } catch (_) {
      error =
          'A sincronização falhou. Suas alterações continuam salvas neste aparelho.';
    } finally {
      syncing = false;
      if (!_disposed) {
        try {
          pending = (await database.pendingNotes(uid)).length;
        } catch (_) {
          error = 'Não foi possível consultar as alterações deste aparelho.';
        }
        if (!_disposed) notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
