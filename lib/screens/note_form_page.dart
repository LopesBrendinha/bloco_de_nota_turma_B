import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/repositories/note_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Formulário de criação/edição. Ao salvar, retorna (via Navigator.pop)
/// `true` se a nota chegou à nuvem ou `false` se ficou só no aparelho.
class NoteFormPage extends StatefulWidget {
  final Note? note;
  final NoteRepository repository;

  const NoteFormPage({super.key, this.note, required this.repository});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  List<String> categories = List.of(Note.defaultCategories);
  String category = Note.defaultCategory;
  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
      category = widget.note!.category;
    }
    loadCategories();
  }

  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final result = await widget.repository.getCategories(user.uid);
    if (!mounted) return;
    setState(() {
      categories = {...result, category}.toList();
    });
  }

  Future<void> newCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: Faculdade'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    setState(() {
      if (!categories.contains(trimmed)) categories.add(trimmed);
      category = trimmed;
    });
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo antes de salvar.')),
      );
      return;
    }

    setState(() => saving = true);
    final note = isEditing
        ? widget.note!.copyWith(title: title, content: content, category: category)
        : Note.create(uid: user.uid, title: title, content: content, category: category);

    final synced = await widget.repository.save(note);
    if (mounted) Navigator.pop(context, synced);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF292333),
              ),
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: c == category,
                    onSelected: (_) => setState(() => category = c),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nova'),
                  onPressed: newCategory,
                ),
              ],
            ),
            const Divider(color: Color(0xFFE4DFEA)),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
