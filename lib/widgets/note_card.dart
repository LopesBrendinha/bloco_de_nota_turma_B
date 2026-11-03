import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/models/sync_status.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:blocodenotasturmab/widgets/highlight_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cartão de nota em forma de folha: margem vermelha de caderno à esquerda,
/// etiqueta de marca-texto com a categoria e trechos da pesquisa destacados.
class NoteCard extends StatelessWidget {
  final Note note;
  final NoteCategory? category;
  final String query;
  final SortField dateField;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.category,
    this.query = '',
    this.dateField = SortField.updated,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = dateField == SortField.created
        ? note.createdAt
        : note.updatedAt;
    final dateLabel = dateField == SortField.created ? 'criada' : 'editada';
    final body = snippetAround(note.content, query);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 18),
                Container(width: 1.4, color: GrafiteColors.margin),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category != null) ...[
                          _CategoryTag(category: category!),
                          const SizedBox(height: 8),
                        ],
                        HighlightText(
                          note.title.isEmpty ? 'Sem título' : note.title,
                          query: query,
                          maxLines: 1,
                          style: GoogleFonts.fraunces(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          HighlightText(
                            body,
                            query: query,
                            maxLines: 2,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              '$dateLabel ${formatShort(date)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (note.syncStatus != SyncStatus.synced) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Aguardando envio para a nuvem',
                                child: Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: GrafiteColors.eraser,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final NoteCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CategoryPalette.of(category.color).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        category.name.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: GrafiteColors.ink,
        ),
      ),
    );
  }
}
