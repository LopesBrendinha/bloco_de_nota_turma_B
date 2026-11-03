import 'dart:async';

import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/services/firestore_service.dart';
import 'package:blocodenotasturmab/services/sync_adapters.dart';
import 'package:blocodenotasturmab/services/sync_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum SyncPhase { idle, syncing, synced, offline, error }

class SyncState {
  final SyncPhase phase;
  final String message;
  final int pending;
  final DateTime? lastSyncedAt;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.message = '',
    this.pending = 0,
    this.lastSyncedAt,
  });
}

/// Orquestra a sincronização: decide quando rodar (abertura do app, após
/// cada alteração, ao recuperar a conexão ou quando o usuário pede), trata
/// os erros e publica o estado para a interface (Observer via ValueNotifier).
class SyncService {
  SyncService({
    required this.uid,
    DatabaseHelper? database,
    FirestoreService? firestore,
    Connectivity? connectivity,
    this.onLocalDataChanged,
  }) : _database = database ?? DatabaseHelper.instance,
       _firestore = firestore ?? FirestoreService(),
       _connectivity = connectivity ?? Connectivity();

  final String uid;
  final DatabaseHelper _database;
  final FirestoreService _firestore;
  final Connectivity _connectivity;
  final VoidCallback? onLocalDataChanged;
  final SyncEngine _engine = const SyncEngine();

  final ValueNotifier<SyncState> state = ValueNotifier(const SyncState());

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;
  bool _running = false;
  bool _runAgain = false;
  bool _disposed = false;

  void start() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (_isOnline(results)) sync();
    });
    sync();
  }

  /// Agrupa várias alterações seguidas em uma única sincronização.
  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), sync);
    _refreshPending();
  }

  Future<void> sync() async {
    if (_disposed) return;
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    try {
      do {
        _runAgain = false;
        await _syncOnce();
      } while (_runAgain && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOnce() async {
    final results = await _connectivity.checkConnectivity();
    if (!_isOnline(results)) {
      await _publish(
        SyncPhase.offline,
        'Sem internet. As alterações ficam salvas no aparelho.',
      );
      return;
    }

    await _publish(SyncPhase.syncing, 'Sincronizando…');
    try {
      final report = await _engine.run([
        // Categorias primeiro, para as notas nunca apontarem para uma
        // categoria que ainda não existe no aparelho.
        CategorySyncAdapter(uid, _database, _firestore),
        NoteSyncAdapter(uid, _database, _firestore),
      ]);
      await _publish(SyncPhase.synced, 'Tudo salvo na nuvem', synced: true);
      if (report.changedLocalData) onLocalDataChanged?.call();
    } on TimeoutException {
      await _publish(
        SyncPhase.offline,
        'O Firebase não respondeu. Tentaremos de novo.',
      );
    } on FirebaseException catch (e) {
      final offline = e.code == 'unavailable' || e.code == 'deadline-exceeded';
      await _publish(
        offline ? SyncPhase.offline : SyncPhase.error,
        _messageFor(e),
      );
    } catch (e) {
      debugPrint('Falha na sincronização: $e');
      await _publish(SyncPhase.error, 'Não foi possível sincronizar.');
    }
  }

  String _messageFor(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Firebase indisponível. As alterações ficam no aparelho.';
      case 'permission-denied':
        return 'Acesso negado pelo Firebase. Verifique as regras de segurança.';
      case 'unauthenticated':
        return 'Sessão expirada. Entre novamente.';
      case 'resource-exhausted':
        return 'Limite do Firebase atingido. Tente mais tarde.';
      default:
        return 'Erro do Firebase (${e.code}).';
    }
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<void> _refreshPending() async {
    final current = state.value;
    await _publish(current.phase, current.message);
  }

  Future<void> _publish(
    SyncPhase phase,
    String message, {
    bool synced = false,
  }) async {
    final pending = await _database.pendingCount(uid);
    if (_disposed) return;
    state.value = SyncState(
      phase: phase,
      message: message,
      pending: pending,
      lastSyncedAt: synced ? DateTime.now() : state.value.lastSyncedAt,
    );
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _connectivitySub?.cancel();
    state.dispose();
  }
}
