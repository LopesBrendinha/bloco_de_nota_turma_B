/// Como terminou uma tentativa de sincronização.
enum SyncState {
  /// Local e nuvem estão iguais.
  synced,

  /// Falhou por falta de conexão. Há operações esperando na fila local.
  offline,

  /// Falhou por outro motivo (permissão, sessão expirada, erro do servidor).
  failed,
}

/// Resultado de uma sincronização, exibido na barra de status da tela de notas.
class SyncOutcome {
  const SyncOutcome({
    required this.state,
    this.message,
    this.pushed = 0,
    this.pulled = 0,
    this.pending = 0,
  });

  final SyncState state;

  /// Mensagem pronta para o usuário quando [state] não é [SyncState.synced].
  final String? message;

  /// Registros enviados para a nuvem nesta rodada.
  final int pushed;

  /// Registros baixados ou atualizados a partir da nuvem.
  final int pulled;

  /// Registros que continuam na fila local aguardando envio.
  final int pending;

  bool get isSynced => state == SyncState.synced;
}
