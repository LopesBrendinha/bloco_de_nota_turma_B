import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../repositories/notes_repository.dart';
import '../widgets/create_category_dialog.dart';

class NoteFormPage extends StatefulWidget {
  final NotesRepository repository;
  final Note? note;

  const NoteFormPage({super.key, required this.repository, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  List<NoteCategory> categories = [];

  String? selectedCategoryId;

  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;

      selectedCategoryId = widget.note!.categoryId;
    }

    loadCategories();
  }

  Future<void> loadCategories() async {
    final result = await widget.repository.getCategories();

    if (mounted) {
      setState(() {
        categories = result;

        // A categoria pode ter sido apagada em outro aparelho.
        if (!categories.any((item) => item.id == selectedCategoryId)) {
          selectedCategoryId = null;
        }
      });
    }
  }

  Future<void> createCategory() async {
    final category = await showCreateCategoryDialog(
      context,
      widget.repository,
    );

    if (category != null) {
      selectedCategoryId = category.id;
      await loadCategories();
    }
  }

  Future<void> saveNote() async {
    // Pegamos os valores digitados.
    final title = titleController.text.trim();

    final content = contentController.text.trim();

    // Verificamos se existe conteúdo.
    if (content.isEmpty) {
      showMessage('Escreva o conteúdo da nota.');
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      // A nota é salva no SQLite e funciona sem internet.
      // O envio para o Firestore acontece depois, em segundo plano.
      await widget.repository.saveNote(
        id: widget.note?.id,
        title: title,
        content: content,
        categoryId: selectedCategoryId,
      );

      // Depois de salvar,
      // voltamos para a tela anterior.
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
        });
        showMessage('Não foi possível salvar a nota.');
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

              inputFormatters: [
                LengthLimitingTextInputFormatter(Note.maxTitleLength),
              ],

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

            const Divider(color: Color(0xFFE4DFEA)),

            Row(
              children: [
                const Icon(
                  Icons.label_outline_rounded,
                  size: 20,
                  color: Color(0xFF77717F),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sem categoria'),
                        ),
                        for (final category in categories)
                          DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),
                  ),
                ),

                TextButton.icon(
                  onPressed: createCategory,
                  icon: const Icon(Icons.add_rounded),
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

                inputFormatters: [
                  LengthLimitingTextInputFormatter(Note.maxContentLength),
                ],

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
