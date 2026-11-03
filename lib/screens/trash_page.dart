import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/sync_service.dart';

/// Lixeira: lista as notas excluídas e permite restaurar ou excluir
/// definitivamente.
class TrashPage extends StatefulWidget {
  final SyncService syncService;

  const TrashPage({super.key, required this.syncService});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final DatabaseHelper database = DatabaseHelper.instance;

  List<Note> notes = [];

  @override
  void initState() {
    super.initState();

    loadNotes();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final result = await database.getTrashedNotes(user.uid);

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> restoreNote(Note note) async {
    // Restaurar é uma alteração comum: limpa o deletedAt e marca a nota
    // como pendente (synced = false). A volta para a lista principal é
    // enviada à nuvem na próxima sincronização.
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.upsertNote(
      note.copyWith(clearDeletedAt: true, updatedAt: now, synced: false),
    );

    await loadNotes();

    showMessage('Nota restaurada.');
  }

  Future<void> deleteForever(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir definitivamente?'),

        content: const Text(
          'Esta nota será apagada do aparelho e da nuvem. '
          'Não será possível recuperá-la.',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Apaga na nuvem e depois no aparelho. Sem conexão, não exclui.
    final report = await widget.syncService.deletePermanently(note);

    await loadNotes();

    showMessage(
      report.success ? 'Nota excluída definitivamente.' : report.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lixeira',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: notes.isEmpty
          ? const Center(
              child: Text(
                'A lixeira está vazia.',
                style: TextStyle(color: Color(0xFF77717F), fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),

              itemCount: notes.length,

              itemBuilder: (context, index) {
                final note = notes[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),

                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),

                  child: Row(
                    children: [
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
                                color: Color(0xFF292333),
                              ),
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

                            const SizedBox(height: 8),

                            Text(
                              'Excluída em ${note.deletedDate}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9A94A1),
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Restaurar',
                        onPressed: () => restoreNote(note),
                        icon: const Icon(
                          Icons.restore_from_trash_rounded,
                          color: Color(0xFF6C4AB6),
                        ),
                      ),

                      IconButton(
                        tooltip: 'Excluir definitivamente',
                        onPressed: () => deleteForever(note),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Color(0xFFB45F6C),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}