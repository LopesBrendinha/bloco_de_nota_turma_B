import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;
  final List<String> categories;

  const NoteFormPage({super.key, this.note, this.categories = const []});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final database = DatabaseHelper.instance;

  bool saving = false;
  String category = Note.defaultCategory;
  List<String> categories = [];

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    category = widget.note?.category ?? Note.defaultCategory;
    categories = {
      Note.defaultCategory,
      'Estudos',
      'Trabalho',
      'Pessoal',
      ...widget.categories,
      category,
    }.toList()..sort();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;
    }
  }

  Future<void> saveNote() async {
    if (saving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Entre na sua conta para salvar a nota.');
      return;
    }

    final title = titleController.text.trim();

    final content = contentController.text.trim();

    if (content.isEmpty) {
      showMessage('Escreva o conteúdo da nota antes de salvar.');
      return;
    }

    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final note = Note(
      id: widget.note?.id,
      uid: user.uid,
      title: title,
      content: content,
      date: date,
      category: category,
    );

    setState(() {
      saving = true;
    });

    try {
      if (isEditing) {
        await database.updateNote(note);
      } else {
        await database.insertNote(note);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      showMessage('Não foi possível salvar a nota. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> addCategory() async {
    String name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
          onChanged: (value) => name = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, name.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    if (result.isEmpty) {
      showMessage('Digite o nome da categoria.');
      return;
    }

    final matching = categories.where(
      (item) => item.toLowerCase() == result.toLowerCase(),
    );

    setState(() {
      if (matching.isNotEmpty) {
        category = matching.first;
      } else {
        category = result;
        categories.add(category);
        categories.sort();
      }
    });
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            tooltip: 'Salvar nota',
            onPressed: saving ? null : saveNote,
            icon: saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
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

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(category),
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: categories.map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: saving ? null : (value) {
                      if (value == null) return;
                      setState(() {
                        category = value;
                      });
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Nova categoria',
                  onPressed: saving ? null : addCategory,
                  icon: const Icon(Icons.add),
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
