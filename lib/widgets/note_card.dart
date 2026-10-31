import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../models/sync_status.dart';
import '../utils/app_date_format.dart';

/// Cartão de uma nota na listagem.
///
/// Mostra três informações que vêm da camada de dados e não apenas do texto:
/// a categoria associada, a data da última atualização e um ícone de "nuvem
/// pendente" quando a nota ainda não foi enviada ao Firestore.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.category,
    required this.onTap,
    required this.trailing,
  });

  final Note note;

  /// Categoria da nota, ou `null` quando ela não tem categoria.
  final NoteCategory? category;

  final VoidCallback onTap;

  /// Botões de ação à direita (excluir, restaurar...).
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final accent = category?.color ?? const Color(0xFF6C4AB6);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.note_rounded, color: accent),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Sem título' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF292333),
                            ),
                          ),
                        ),

                        if (note.syncStatus != SyncStatus.synced)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: 'Aguardando envio para o Firebase',
                              child: Icon(
                                Icons.cloud_off_rounded,
                                size: 16,
                                color: Color(0xFF9A94A1),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77717F),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (category != null) _CategoryTag(category: category!),

                        Text(
                          AppDateFormat.friendly(note.updatedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A94A1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              trailing,
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: category.color,
        ),
      ),
    );
  }
}
