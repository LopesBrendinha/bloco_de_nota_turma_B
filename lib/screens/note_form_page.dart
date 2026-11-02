import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/note.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;
  final List<String> categories;
  const NoteFormPage({super.key, this.note, required this.categories});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final database = DatabaseHelper.instance;
  late List<String> categories;
  late String category;
  bool saving = false;
  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.note?.title ?? '';
    contentController.text = widget.note?.content ?? '';
    category = widget.note?.category ?? 'Pessoal';
    categories = {...widget.categories, category}.toList()..sort();
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
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      setState(() {
        category = categories.firstWhere(
          (item) => item.toLowerCase() == name.toLowerCase(),
          orElse: () => name,
        );
        categories = {...categories, category}.toList()..sort();
      });
    }
    // O diálogo pode continuar na animação de saída após devolver o resultado.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<void> saveNote() async {
    if (saving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (widget.note != null && widget.note!.uid != user.uid)) {
      return;
    }
    if (contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva o conteúdo da nota.')),
      );
      return;
    }
    setState(() => saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedAt = now > (widget.note?.updatedAt ?? 0)
        ? now
        : widget.note!.updatedAt + 1;
    final note = Note(
      id: widget.note?.id,
      cloudId: widget.note?.cloudId ?? const Uuid().v4(),
      uid: user.uid,
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      category: category,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: updatedAt,
      archived: widget.note?.archived ?? false,
      changeId: const Uuid().v4(),
    );
    try {
      await database.saveNote(note);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a nota neste aparelho.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        isEditing ? 'Editar nota' : 'Nova nota',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          tooltip: 'Salvar nota',
          onPressed: saving ? null : saveNote,
          icon: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(category),
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => category = value!),
                ),
              ),
              IconButton(
                tooltip: 'Nova categoria',
                onPressed: saving ? null : newCategory,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            maxLength: 120,
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
          const Divider(color: Color(0xFFE4DFEA)),
          Expanded(
            child: TextField(
              controller: contentController,
              maxLength: 20000,
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
