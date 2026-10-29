String _two(int n) => n.toString().padLeft(2, '0');

/// Formata a data como `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year} '
    '${_two(date.hour)}:${_two(date.minute)}';
