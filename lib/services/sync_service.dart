import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de uma sincronização, para a tela saber o que mostrar.
class SyncReport {
  final bool success;
  final String message;

  const SyncReport.ok() : success = true, message = '';
  const SyncReport.failed(this.message) : success = false;
}

/// Mantém o SQLite (local) e o Firestore (nuvem) iguais.
///
/// Estratégia: "local primeiro".
///  - O app sempre lê e grava no SQLite, então funciona sem internet.
///  - Toda alteração local marca a nota com synced = false.
///  - Quando há conexão, as notas pendentes são enviadas e as notas
///    novas ou mais recentes da nuvem são baixadas.
///  - Em conflito (a mesma nota alterada em dois lugares), vale a de
///    updatedAt mais recente ("a última alteração vence").
class SyncService {
  SyncService({DatabaseHelper? local, FirestoreService? remote})
    : _local = local ?? DatabaseHelper.instance,
      _remote = remote ?? FirestoreService();

  final DatabaseHelper _local;
  final FirestoreService _remote;

  bool _running = false;

  Future<SyncReport> sync(String uid) async {
    // Evita duas sincronizações ao mesmo tempo.
    if (_running) return const SyncReport.ok();
    _running = true;

    try {
      // 1) Estado atual da nuvem e do aparelho.
      final remoteNotes = await _remote.fetchNotes(uid);
      final remoteById = {for (final n in remoteNotes) n.id: n};

      final localNotes = await _local.getAllNotes(uid);
      final localById = {for (final n in localNotes) n.id: n};

      // 2) Enviar as alterações locais pendentes.
      for (final local in localNotes.where((n) => !n.synced)) {
        final remote = remoteById[local.id];

        // A versão da nuvem é mais nova: ela vence e será baixada no
        // passo 3. Não sobrescrevemos com a versão local antiga.
        if (remote != null && remote.updatedAt > local.updatedAt) continue;

        await _remote.saveNote(local);
        await _local.markAsSynced(local.id);
      }

      // 3) Baixar notas novas ou mais recentes da nuvem.
      for (final remote in remoteNotes) {
        final local = localById[remote.id];

        if (local == null || remote.updatedAt > local.updatedAt) {
          await _local.upsertNote(remote);
        }

        // Garante que a categoria da nota exista na lista local.
        await _local.insertCategory(uid, remote.category);
      }

      return const SyncReport.ok();
    } on TimeoutException {
      return const SyncReport.failed(
        'Sem conexão com a nuvem. As notas continuam salvas no aparelho '
        'e serão enviadas quando a conexão voltar.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const SyncReport.failed(
          'Sem permissão para acessar as notas na nuvem. '
          'Verifique as regras do Firestore e o login.',
        );
      }
      if (e.code == 'unavailable') {
        return const SyncReport.failed(
          'Não foi possível acessar o Firebase agora. '
          'As notas continuam salvas no aparelho.',
        );
      }
      return SyncReport.failed('Erro na sincronização (${e.code}).');
    } catch (_) {
      return const SyncReport.failed(
        'Erro inesperado ao sincronizar. Suas notas locais estão seguras.',
      );
    } finally {
      _running = false;
    }
  }
}