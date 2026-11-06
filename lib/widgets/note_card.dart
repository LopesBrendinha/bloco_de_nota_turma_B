import 'package:blocodenotasturmab/models/note.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
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
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
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
                      note.title.isEmpty ? 'Sem Título' : note.title,
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffede5fa),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            note.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff6c4ab6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            note.formattedDate,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff9a94a1),
                            ),
                          ),
                        ),
                        if (!note.synced) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Ainda não enviada ao Firebase',
                            child: Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: Color(0xff9a94a1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: note.archived ? 'Desarquivar' : 'Arquivar',
                    onPressed: onArchive,
                    icon: Icon(
                      note.archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      color: const Color(0xff6c4ab6),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xffb45f6c),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
