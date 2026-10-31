/// Normalização de texto usada pela pesquisa.
///
/// A pesquisa do SQLite usa `LIKE`, que com a collation `NOCASE` só ignora
/// maiúsculas de letras ASCII: "ANIVERSÁRIO" não encontra "Aniversário"
/// porque o `Á` fica de fora. Como o aplicativo é em português, isso
/// quebraria a pesquisa em boa parte das palavras.
///
/// A solução é gravar em cada nota uma coluna `search_text` já normalizada
/// (minúsculas e sem acentos) e normalizar também o termo digitado. Assim a
/// comparação é feita entre dois textos no mesmo formato, e procurar por
/// "aniversario", "Aniversário" ou "ANIVERSÁRIO" dá o mesmo resultado.
class TextNormalizer {
  const TextNormalizer._();

  static const _accents = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Devolve o texto em minúsculas e sem acentos.
  static String normalize(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();

    for (final character in lower.split('')) {
      buffer.write(_accents[character] ?? character);
    }

    return buffer.toString();
  }

  /// Texto indexado de uma nota: título e conteúdo juntos, normalizados.
  static String forNote({required String title, required String content}) {
    return normalize('$title $content');
  }
}
