import 'package:flutter/material.dart';

import '../repositories/note_repository.dart';
import '../utils/date_format.dart';

/// Ícone na barra superior que mostra o estado da sincronização e, ao ser
/// tocado, sincroniza manualmente.
class SyncStatusButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SyncStatusButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncInfo>(
      valueListenable: NoteRepository.instance.syncInfo,
      builder: (context, info, _) {
        final (icon, color, text) = switch (info.state) {
          SyncState.idle => (Icons.cloud_outlined, null, 'Sincronizar'),
          SyncState.syncing => (Icons.cloud_sync_outlined, null, 'Sincronizando...'),
          SyncState.synced when info.pending > 0 => (
            Icons.cloud_upload_outlined,
            Colors.orange,
            '${info.pending} alteração(ões) aguardando envio',
          ),
          SyncState.synced => (
            Icons.cloud_done_outlined,
            Colors.green,
            'Sincronizado'
                '${info.lastSync == null ? '' : ' em ${formatDateTime(info.lastSync!)}'}',
          ),
          SyncState.offline => (
            Icons.cloud_off_outlined,
            Colors.orange,
            'Offline: ${info.pending} alteração(ões) salvas só no aparelho',
          ),
          SyncState.error => (
            Icons.error_outline,
            Colors.red,
            info.message ?? 'Erro ao sincronizar',
          ),
        };

        return IconButton(
          tooltip: text,
          onPressed: info.state == SyncState.syncing ? null : onPressed,
          icon: info.state == SyncState.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: color),
        );
      },
    );
  }
}
