import 'package:flutter/material.dart';

import '../repositories/sync_outcome.dart';

/// Faixa que informa o estado da sincronização com o Firebase.
///
/// Requisito de "tratar erros de conexão": quando o Firestore não responde,
/// o aplicativo continua funcionando com o SQLite e esta faixa explica o que
/// aconteceu e quantas notas ainda estão na fila, em vez de falhar em
/// silêncio ou travar a tela.
class SyncBanner extends StatelessWidget {
  const SyncBanner({
    super.key,
    required this.outcome,
    required this.isSyncing,
    required this.onRetry,
  });

  final SyncOutcome? outcome;
  final bool isSyncing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return const _Banner(
        color: Color(0xFFEDE5FA),
        foreground: Color(0xFF5A3FA0),
        icon: Icons.cloud_sync_rounded,
        text: 'Sincronizando com o Firebase...',
      );
    }

    final result = outcome;

    if (result == null || result.isSynced && result.pending == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = result.state == SyncState.offline;

    return _Banner(
      color: isOffline ? const Color(0xFFFDF2E3) : const Color(0xFFFBE9EC),
      foreground: isOffline ? const Color(0xFF9A6413) : const Color(0xFF9B2F43),
      icon: isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
      text: result.message ??
          '${result.pending} nota(s) aguardando envio para a nuvem.',
      onRetry: onRetry,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: foreground, height: 1.3),
            ),
          ),

          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}
