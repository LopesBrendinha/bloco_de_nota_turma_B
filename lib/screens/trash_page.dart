import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../widgets/note_card.dart';

/// Lixeira: notas excluídas temporariamente, que podem ser restauradas
/// ou apagadas de vez (do aparelho e da nuvem).
class TrashPage extends StatefulWidget {
  final NoteRepository repository;

  const TrashPage({super.key, required this.repository});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<Note> notes = [];

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final uid = this.uid;
    if (uid == null) return;
    final result = await widget.repository.getTrash(uid);
    if (mounted) setState(() => notes = result);
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir definitivamente?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> restore(Note note) async {
    await widget.repository.restore(note);
    await load();
    showMessage('Nota restaurada.');
  }

  Future<void> deleteForever(Note note) async {
    if (!await confirm('Esta nota não poderá ser recuperada.')) return;
    final ok = await widget.repository.deleteForever(note);
    await load();
    showMessage(ok ? 'Nota excluída.' : 'Excluída no aparelho. A nuvem será atualizada quando houver conexão.');
  }

  Future<void> emptyTrash() async {
    final uid = this.uid;
    if (uid == null || notes.isEmpty) return;
    if (!await confirm('Todas as ${notes.length} notas da lixeira serão apagadas.')) return;
    final ok = await widget.repository.emptyTrash(uid);
    await load();
    showMessage(ok ? 'Lixeira esvaziada.' : 'Lixeira esvaziada no aparelho. A nuvem será atualizada quando houver conexão.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lixeira', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: notes.isEmpty ? null : emptyTrash,
            child: const Text('Esvaziar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Text('A lixeira está vazia.', style: TextStyle(color: Color(0xFF77717F))),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteCard(
                  note: note,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Restaurar',
                        onPressed: () => restore(note),
                        icon: const Icon(Icons.restore_rounded, color: Color(0xFF6C4AB6)),
                      ),
                      IconButton(
                        tooltip: 'Excluir definitivamente',
                        onPressed: () => deleteForever(note),
                        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFB45F6C)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
