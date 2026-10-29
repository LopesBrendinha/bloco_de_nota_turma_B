import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../widgets/note_card.dart';

/// Lixeira com recuperação: notas excluídas ficam aqui até serem
/// restauradas, excluídas definitivamente ou completarem 30 dias.
class TrashPage extends StatefulWidget {
  final User user;

  const TrashPage({super.key, required this.user});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final repository = NoteRepository.instance;
  List<Note> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repository.changes.addListener(loadTrash);
    loadTrash();
  }

  @override
  void dispose() {
    repository.changes.removeListener(loadTrash);
    super.dispose();
  }

  Future<void> loadTrash() async {
    final result = await repository.getTrash(widget.user.uid);
    if (mounted) {
      setState(() {
        notes = result;
        loading = false;
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffb45f6c),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> restore(Note note) async {
    await repository.restoreFromTrash(note);
    await loadTrash();
    if (mounted) _message('Nota restaurada.');
  }

  Future<void> deleteForever(Note note) async {
    final ok = await _confirm(
      'Excluir definitivamente?',
      'A nota será apagada deste aparelho e da nuvem. Não é possível desfazer.',
    );
    if (!ok) return;
    await repository.deletePermanently(note);
    await loadTrash();
    if (mounted) _message('Nota excluída definitivamente.');
  }

  Future<void> emptyTrash() async {
    final ok = await _confirm(
      'Esvaziar lixeira?',
      'Todas as ${notes.length} nota(s) da lixeira serão apagadas '
          'definitivamente.',
    );
    if (!ok) return;
    await repository.emptyTrash(widget.user.uid);
    await loadTrash();
    if (mounted) _message('Lixeira esvaziada.');
  }

  int _daysLeft(Note note) {
    final expires = note.deletedAt!.add(NoteRepository.trashRetention);
    return expires.difference(DateTime.now()).inDays.clamp(0, 30);
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
            TextButton.icon(
              onPressed: emptyTrash,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Esvaziar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 64,
                    color: Color(0xFFB9B3C2),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'A lixeira está vazia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'As notas ficam aqui por 30 dias e depois são excluídas '
                    'automaticamente.',
                    style: TextStyle(color: Color(0xFF77717F)),
                  ),
                ),
                for (final note in notes)
                  NoteCard(
                    note: note,
                    dateLabel: 'Excluída em',
                    date: note.deletedAt,
                    actions: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Restaurar',
                            onPressed: () => restore(note),
                            icon: const Icon(
                              Icons.restore_rounded,
                              color: Color(0xff6c4ab6),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                'Excluir definitivamente '
                                '(${_daysLeft(note)} dia(s) restantes)',
                            onPressed: () => deleteForever(note),
                            icon: const Icon(
                              Icons.delete_forever_outlined,
                              color: Color(0xffb45f6c),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
