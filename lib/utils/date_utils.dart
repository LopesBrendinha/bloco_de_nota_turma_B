const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime fromMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis).toLocal();

/// 02/11/2026 14:05
String formatDateTime(int millis) {
  final d = fromMillis(millis);
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

/// "14:05" se for hoje, "ontem" ou "02/11" caso contrário.
String formatShort(int millis, {DateTime? now}) {
  final d = fromMillis(millis);
  final today = _day(now ?? DateTime.now());
  final diff = today.difference(_day(d)).inDays;
  if (diff == 0) return '${_two(d.hour)}:${_two(d.minute)}';
  if (diff == 1) return 'ontem';
  if (d.year == today.year) return '${_two(d.day)}/${_two(d.month)}';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Rótulo da seção em que a nota aparece quando a lista é agrupada por data.
String dateGroupLabel(int millis, {DateTime? now}) {
  final d = fromMillis(millis);
  final reference = now ?? DateTime.now();
  final diff = _day(reference).difference(_day(d)).inDays;
  if (diff <= 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  if (diff < 7) return 'Últimos 7 dias';
  if (d.year == reference.year && d.month == reference.month) {
    return 'Este mês';
  }
  final month = _months[d.month - 1];
  final capitalized = month[0].toUpperCase() + month.substring(1);
  return d.year == reference.year ? capitalized : '$capitalized de ${d.year}';
}
