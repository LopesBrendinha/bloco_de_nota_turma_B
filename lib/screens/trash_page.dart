import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/sync_service.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final database = DatabaseHelper.instance;
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await database.getNotes(user.uid, trashed: true);
    if (mounted) setState(() => notes = result);
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> restore(Note note) async {
    final restored = note.copyWith(
      deleted: false,
      synced: false,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await database.updateNote(restored);
    final sent = await SyncService.instance.push(restored);
    await load();

    if (mounted) {
      _msg(
        sent
            ? 'Nota recuperada.'
            : 'Nota recuperada (ainda não enviada ao Firebase).',
      );
    }
  }

  Future<void> deleteForever(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir definitivamente?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await SyncService.instance.deleteRemote(note.uid, note.syncId);
    if (!ok) {
      if (mounted) {
        _msg('Sem conexão com o Firebase. Tente excluir novamente online.');
      }
      return;
    }

    await database.deleteNoteForever(note.syncId);
    await load();
    if (mounted) _msg('Nota excluída definitivamente.');
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
          ? const Center(child: Text('A lixeira está vazia.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      note.title.isEmpty ? note.content : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${note.category} · ${note.date}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Recuperar',
                          icon: const Icon(Icons.restore_from_trash_rounded),
                          onPressed: () => restore(note),
                        ),
                        IconButton(
                          tooltip: 'Excluir definitivamente',
                          icon: const Icon(Icons.delete_forever_rounded),
                          onPressed: () => deleteForever(note),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
