const _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Deixa o texto em minúsculas e sem acentos, para que "Ação" encontre
/// "acao". Cada caractere vira exatamente um caractere, então as posições do
/// texto normalizado batem com as do original (usado no destaque da busca).
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.split('')) {
    final lower = char.toLowerCase();
    buffer.write(lower.length == 1 ? (_accents[lower] ?? lower) : char);
  }
  return buffer.toString();
}
