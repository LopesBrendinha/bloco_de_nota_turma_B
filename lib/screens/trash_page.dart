import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../repositories/note_repository.dart';
import '../utils/app_date_format.dart';
import '../widgets/note_card.dart';

/// Lixeira com recuperação — a funcionalidade adicional do projeto.
///
/// Excluir uma nota na listagem **não** apaga nada: marca `is_deleted = 1`
/// no SQLite e `isDeleted: true` no Firestore. Esta tela mostra essas notas
/// e permite restaurá-las ou apagá-las de vez, nos dois armazenamentos.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final NoteRepository repository = NoteRepository();

  List<Note> notes = [];
  List<NoteCategory> categories = [];
  bool loading = true;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (uid.isEmpty) return;

    final trashed = await repository.getTrashedNotes(uid: uid);
    final allCategories = await repository.getCategories(uid);

    if (!mounted) return;

    setState(() {
      notes = trashed;
      categories = allCategories;
      loading = false;
    });
  }

  Future<void> restore(Note note) async {
    await repository.restoreFromTrash(note);
    await load();

    if (mounted) _showSnack('Nota restaurada.');
  }

  Future<void> deleteForever(Note note) async {
    final confirmed = await _confirm(
      title: 'Excluir definitivamente?',
      message:
          'A nota será removida do aparelho e do Firebase. '
          'Esta ação não pode ser desfeita.',
    );

    if (!confirmed) return;

    final outcome = await repository.deleteForever(note);
    await load();

    if (!mounted) return;

    _showSnack(
      outcome.isSynced
          ? 'Nota excluída definitivamente.'
          : outcome.message ?? 'Exclusão pendente de envio para a nuvem.',
    );
  }

  Future<void> emptyTrash() async {
    final confirmed = await _confirm(
      title: 'Esvaziar a lixeira?',
      message:
          'Todas as ${notes.length} nota(s) serão removidas do aparelho e do '
          'Firebase. Esta ação não pode ser desfeita.',
    );

    if (!confirmed) return;

    final outcome = await repository.emptyTrash(uid);
    await load();

    if (!mounted) return;

    _showSnack(
      outcome.isSynced
          ? 'Lixeira esvaziada.'
          : outcome.message ?? 'Exclusões pendentes de envio para a nuvem.',
    );
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB45F6C),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  NoteCategory? _categoryOf(Note note) {
    if (note.categoryId == null) return null;

    for (final category in categories) {
      if (category.id == note.categoryId) return category;
    }

    return null;
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
            TextButton(
              onPressed: emptyTrash,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB45F6C),
              ),
              child: const Text('Esvaziar'),
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (notes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 60,
              color: Color(0xFF9A94A1),
            ),
            SizedBox(height: 16),
            Text(
              'A lixeira está vazia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Notas excluídas ficam aqui até você apagá-las de vez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF77717F)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoteCard(
              note: note,
              category: _categoryOf(note),
              onTap: () => restore(note),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Restaurar',
                    onPressed: () => restore(note),
                    icon: const Icon(
                      Icons.restore_from_trash_rounded,
                      color: Color(0xFF2F9E7E),
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
            ),

            if (note.deletedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 14),
                child: Text(
                  'Excluída ${AppDateFormat.friendly(note.deletedAt!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9A94A1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
