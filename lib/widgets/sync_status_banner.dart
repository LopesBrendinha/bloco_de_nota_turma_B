import 'package:flutter/material.dart';

import '../models/sync_status.dart';
import '../services/remote_data_source.dart';
import '../utils/date_utils.dart';

/// Faixa que mostra se as notas estão salvas na nuvem ou se há algo pendente.
class SyncStatusBanner extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback onRetry;

  const SyncStatusBanner({
    super.key,
    required this.status,
    required this.onRetry,
  });

  /// Texto exibido para cada situação da sincronização.
  static String messageFor(SyncStatus status) {
    final pending = status.pendingChanges;
    final waiting = pending == 1
        ? '1 alteração será enviada'
        : '$pending alterações serão enviadas';

    switch (status.failure) {
      case RemoteErrorKind.offline:
        return pending > 0
            ? 'Sem conexão. $waiting quando a internet voltar.'
            : 'Sem conexão. Mostrando as notas salvas neste aparelho.';
      case RemoteErrorKind.permissionDenied:
        return 'O Firebase recusou o acesso. Suas notas seguem neste aparelho.';
      case RemoteErrorKind.unauthenticated:
        return 'Sua sessão expirou. Saia e entre novamente para sincronizar.';
      case RemoteErrorKind.quotaExceeded:
        return 'Limite de uso do Firebase atingido. Suas notas seguem neste aparelho.';
      case RemoteErrorKind.unknown:
        return 'Não foi possível sincronizar. Suas notas seguem neste aparelho.';
      case null:
        break;
    }

    if (status.isSyncing) return 'Sincronizando...';
    if (pending > 0) return '$waiting em instantes.';

    final lastSync = status.lastSyncAt;
    return lastSync == null
        ? 'Notas salvas neste aparelho.'
        : 'Tudo salvo na nuvem às ${formatTime(lastSync)}.';
  }

  @override
  Widget build(BuildContext context) {
    final failed = status.state == SyncState.failed;
    final color = failed ? Color(0xffb45f6c) : Color(0xff77717f);

    return Row(
      children: [
        if (status.isSyncing)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            failed ? Icons.cloud_off_rounded : Icons.cloud_done_outlined,
            size: 16,
            color: color,
          ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            messageFor(status),
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
        if (failed)
          TextButton(onPressed: onRetry, child: Text('Tentar de novo')),
      ],
    );
  }
}
