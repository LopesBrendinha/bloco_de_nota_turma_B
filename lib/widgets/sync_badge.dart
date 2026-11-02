import 'package:blocodenotasturmab/services/sync_service.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Indicador de sincronização na barra superior. Toque para sincronizar.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.state, required this.onSync});

  final ValueListenable<SyncState> state;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: state,
      builder: (context, value, _) {
        final colors = Theme.of(context).colorScheme;
        final (icon, color) = switch (value.phase) {
          SyncPhase.syncing => (Icons.sync_rounded, colors.onSurfaceVariant),
          SyncPhase.synced when value.pending == 0 => (
            Icons.cloud_done_outlined,
            colors.onSurface,
          ),
          SyncPhase.offline => (
            Icons.cloud_off_outlined,
            colors.onSurfaceVariant,
          ),
          SyncPhase.error => (
            Icons.error_outline_rounded,
            GrafiteColors.eraser,
          ),
          _ => (Icons.cloud_upload_outlined, colors.onSurfaceVariant),
        };

        return Tooltip(
          message: _describe(value),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await onSync();
              messenger.showSnackBar(
                SnackBar(content: Text(_describe(state.value))),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  value.phase == SyncPhase.syncing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      : Icon(icon, size: 20, color: color),
                  if (value.pending > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: GrafiteColors.highlighter,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${value.pending}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GrafiteColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _describe(SyncState value) {
    final buffer = StringBuffer(
      value.message.isEmpty ? 'Aguardando sincronização' : value.message,
    );
    if (value.pending > 0) {
      buffer.write(
        ' · ${value.pending} ${value.pending == 1 ? 'alteração pendente' : 'alterações pendentes'}',
      );
    }
    final last = value.lastSyncedAt;
    if (last != null) {
      buffer.write(
        ' · última sincronização ${formatShort(last.millisecondsSinceEpoch)}',
      );
    }
    return buffer.toString();
  }
}
