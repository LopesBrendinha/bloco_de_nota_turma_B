import 'package:flutter/material.dart';

import '../models/note.dart';
import '../utils/date_format.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  /// Botões exibidos à direita (lixeira, restaurar, excluir...).
  final List<Widget> actions;

  /// Texto da data exibida (ex.: "Editada em", "Na lixeira desde").
  final String dateLabel;
  final DateTime? date;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.actions = const [],
    this.dateLabel = 'Atualizada em',
    this.date,
  });

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xffede5fa),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.note_rounded, color: Color(0xff6c4ab6)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Sem título' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff292333),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff77717f),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CategoryTag(name: note.category),
                        Text(
                          '$dateLabel ${formatDateTime(date ?? note.updatedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff9a94a1),
                          ),
                        ),
                        if (note.syncStatus != SyncStatus.synced)
                          const Tooltip(
                            message: 'Aguardando envio para a nuvem',
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 14,
                              color: Color(0xff9a94a1),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String name;
  const _CategoryTag({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xffede5fa),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xff6c4ab6),
        ),
      ),
    );
  }
}
