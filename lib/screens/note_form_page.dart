import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../widgets/new_category_dialog.dart';

/// Tela de criação e edição de nota.
class NoteFormPage extends StatefulWidget {
  final User user;
  final Note? note;

  const NoteFormPage({super.key, required this.user, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final repository = NoteRepository.instance;

  List<String> categories = [];
  late String category;
  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    category = widget.note?.category ?? Note.defaultCategory;
    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
    }
    loadCategories();
  }

  Future<void> loadCategories() async {
    final names = await repository.getCategoryNames(widget.user.uid);
    // Garante que a categoria atual apareça, mesmo que tenha vindo de outro
    // aparelho e ainda não esteja na lista local.
    if (!names.contains(category)) names.add(category);
    if (mounted) setState(() => categories = names);
  }

  Future<void> createCategory() async {
    final name = await showNewCategoryDialog(context);
    if (name == null) return;
    final saved = await repository.addCategory(widget.user.uid, name);
    await loadCategories();
    if (mounted) setState(() => category = saved);
  }

  Future<void> saveNote() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva um título ou conteúdo.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      if (isEditing) {
        await repository.updateNote(
          widget.note!.copyWith(
            title: title,
            content: content,
            category: category,
          ),
        );
      } else {
        await repository.createNote(
          uid: widget.user.uid,
          title: title,
          content: content,
          category: category,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar a nota: $e')));
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar nota' : 'Nova nota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            onPressed: saving ? null : saveNote,
            icon: const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              maxLength: 200,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF292333),
              ),
              decoration: const InputDecoration(
                hintText: 'Título',
                counterText: '',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.label_outline,
                  size: 20,
                  color: Color(0xFF77717F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: categories.contains(category) ? category : null,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Categoria'),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => category = value);
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: createCategory,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE4DFEA)),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                // Mesmo limite validado em firestore.rules.
                maxLength: 20000,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
