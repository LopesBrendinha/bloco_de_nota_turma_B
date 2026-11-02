import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/utils/text_normalizer.dart';
import 'package:flutter/material.dart';

/// Texto com os trechos que casam com a pesquisa marcados de marca-texto.
/// A comparação ignora maiúsculas e acentos, igual à busca no SQLite.
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final term = normalizeForSearch(query.trim());
    final normalized = normalizeForSearch(text);
    final canHighlight = term.isNotEmpty && normalized.length == text.length;

    if (!canHighlight) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    var start = 0;
    var index = normalized.indexOf(term);
    while (index >= 0) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + term.length),
          style: const TextStyle(
            backgroundColor: GrafiteColors.highlighter,
            color: GrafiteColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = index + term.length;
      index = normalized.indexOf(term, start);
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Recorta o conteúdo em volta da primeira ocorrência da pesquisa, para que
/// o trecho encontrado apareça no cartão mesmo em notas longas.
String snippetAround(String content, String query, {int before = 40}) {
  final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  final term = normalizeForSearch(query.trim());
  if (term.isEmpty) return flat;
  final index = normalizeForSearch(flat).indexOf(term);
  if (index <= before) return flat;
  final cut = flat.indexOf(' ', index - before);
  final from = cut < 0 || cut >= index ? index - before : cut + 1;
  return '…${flat.substring(from)}';
}
