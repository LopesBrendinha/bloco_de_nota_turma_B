String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formata milissegundos desde 1970 como `dd/MM/aaaa HH:mm` no horário local.
String formatDateTime(int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year} '
      '${formatTime(millis)}';
}

/// Formata milissegundos desde 1970 como `HH:mm` no horário local.
String formatTime(int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

/// Converte o formato de data do banco antigo (`dd/MM/aaaa HH:mm`).
///
/// Retorna null quando o texto não está nesse formato.
int? parseLegacyDate(String text) {
  final match = RegExp(
    r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$',
  ).firstMatch(text.trim());
  if (match == null) return null;

  return DateTime(
    int.parse(match[3]!),
    int.parse(match[2]!),
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
  ).millisecondsSinceEpoch;
}

/// Próximo valor de `updatedAt` para um registro.
///
/// Garante que o valor sempre aumenta, mesmo com duas edições no mesmo
/// milissegundo ou com o relógio do aparelho atrasado. A sincronização
/// depende disso para perceber que o registro mudou.
int nextTimestamp(int? previous, {DateTime? now}) {
  final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
  if (previous == null || current > previous) return current;
  return previous + 1;
}
