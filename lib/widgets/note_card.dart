import 'package:blocodenotasturmab/models/note.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Substitui o botão de excluir (usado na lixeira para restaurar/apagar).
  final Widget? trailing;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xffede5fa),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.note_rounded, color: Color(0xff6c4ab6)),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? "Sem Título" : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff292333),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xff77717f), height: 1.4),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xfff1ecfa),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            note.category,
                            style: TextStyle(fontSize: 11, color: Color(0xff6c4ab6)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          note.formattedDate,
                          style: TextStyle(fontSize: 11, color: Color(0xff9a94a1)),
                        ),
                        if (!note.synced) ...[
                          SizedBox(width: 6),
                          Tooltip(
                            message: 'Aguardando sincronização',
                            child: Icon(
                              Icons.cloud_off_rounded,
                              key: Key('pending-sync'),
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
              trailing ??
                  IconButton(
                    tooltip: 'Mover para a lixeira',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xffb45f6c),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
