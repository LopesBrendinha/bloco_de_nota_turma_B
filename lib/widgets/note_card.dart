import 'package:flutter/material.dart';
import '../models/note.dart';

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
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE5FA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                note.archived ? Icons.archive_outlined : Icons.notes_rounded,
                color: const Color(0xFF6C4AB6),
              ),
            ),
            const SizedBox(width: 14),
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
                      color: Color(0xFF292333),
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  Text(
                    note.category,
                    style: const TextStyle(
                      color: Color(0xFF6C4AB6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        note.date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF77717F),
                        ),
                      ),
                      Icon(
                        note.synced
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_upload_outlined,
                        size: 15,
                        color: note.synced
                            ? const Color(0xFF588064)
                            : const Color(0xFF9A7942),
                      ),
                      Text(
                        note.synced ? 'Sincronizada' : 'Pendente',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF77717F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções da nota',
              onSelected: (value) =>
                  value == 'archive' ? onArchive() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(note.archived ? 'Desarquivar' : 'Arquivar'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
