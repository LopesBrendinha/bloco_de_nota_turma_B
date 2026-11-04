import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/notes_repository.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/note_card.dart';

/// Lixeira: as notas ficam aqui até serem recuperadas ou apagadas de vez.
class TrashPage extends StatefulWidget {
  final NotesRepository repository;

  const TrashPage({super.key, required this.repository});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<Note> notes = [];
  bool loading = true;

  NotesRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();

    repository.addListener(loadNotes);
    loadNotes();
  }

  Future<void> loadNotes() async {
    final result = await repository.getTrashedNotes();

    if (mounted) {
      setState(() {
        notes = result;
        loading = false;
      });
    }
  }

  Future<void> restoreNote(Note note) async {
    await repository.restoreNote(note.id);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nota recuperada.')));
    }
  }

  Future<void> deleteNote(Note note) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir definitivamente?',
      message: 'A nota será apagada deste aparelho e da nuvem.',
      confirmLabel: 'Excluir',
    );

    if (confirmed) {
      await repository.deleteNotePermanently(note.id);
    }
  }

  Future<void> emptyTrash() async {
    final confirmed = await confirmAction(
      context,
      title: 'Esvaziar a lixeira?',
      message: 'Todas as notas da lixeira serão apagadas definitivamente.',
      confirmLabel: 'Esvaziar',
    );

    if (confirmed) {
      await repository.emptyTrash();
    }
  }

  @override
  void dispose() {
    repository.removeListener(loadNotes);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lixeira',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          if (notes.isNotEmpty)
            TextButton(onPressed: emptyTrash, child: const Text('Esvaziar')),

          const SizedBox(width: 8),
        ],
      ),

      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      return const Center(
        child: Text(
          'A lixeira está vazia.',
          style: TextStyle(color: Color(0xFF77717F)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),

      itemCount: notes.length,

      itemBuilder: (context, index) {
        final note = notes[index];

        return NoteCard(
          note: note,

          actions: [
            IconButton(
              tooltip: 'Recuperar',
              onPressed: () => restoreNote(note),
              icon: const Icon(
                Icons.restore_from_trash_rounded,
                color: Color(0xFF6C4AB6),
              ),
            ),

            IconButton(
              tooltip: 'Excluir definitivamente',
              onPressed: () => deleteNote(note),
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFB45F6C),
              ),
            ),
          ],
        );
      },
    );
  }
}
