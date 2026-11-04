/// Letras acentuadas usadas em português e suas versões sem acento.
const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Marcas de acento combinantes do Unicode (texto em forma decomposta).
final RegExp _combiningMarks = RegExp('[̀-ͯ]');

/// Prepara um texto para pesquisa: minúsculas e sem acentos.
///
/// O LOWER() do SQLite só trata letras ASCII, então "REUNIÃO" e "reuniao"
/// não seriam encontrados um pelo outro. Por isso guardamos na coluna
/// `search_text` o texto já normalizado aqui, em Dart.
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().replaceAll(_combiningMarks, '').split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Escapa `%`, `_` e `\` para que sejam tratados como texto comum no LIKE.
String escapeLike(String term) {
  return term.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
}
