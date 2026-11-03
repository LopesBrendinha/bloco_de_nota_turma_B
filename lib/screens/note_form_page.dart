

import 'package:blocodenotasturmab/repositories/note_repository.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final repository = NoteRepository();

  bool saving = false;

  bool get isEditing => widget.note != null;

  static const newCategoryOption = '__nova_categoria__';

  List<String> categories = [];

  String selectedCategory = '';

  @override
  void initState() {
    super.initState();


    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;
      selectedCategory = widget.note?.category ?? '';
    }

    loadCategories();
  }

  Future<void> saveNote() async {
    // Pegamos o usuário atualmente autenticado.
    final user = FirebaseAuth.instance.currentUser;

    // Sem usuário não podemos salvar.
    if (user == null) return;

    // Pegamos os valores digitados.
    final title = titleController.text.trim();

    final content = contentController.text.trim();

    // Verificamos se existe conteúdo.
    if (content.isEmpty) {
      return;
    }

    setState(() {
      saving = true;
    });

    // Criamos a data da alteração.
    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // Criamos um objeto Note.
    //
    // Se estamos editando:
    //     widget.note?.id
    // mantém o ID existente.
    //
    // Se estamos criando:
    //     o ID será null.
    final note = Note(
      id: widget.note?.id,
      remoteId: widget.note?.remoteId,
      uid: user.uid,
      title: title,
      category: selectedCategory,
      content: content,
      date: date,
      completed: widget.note?.completed ?? false,
    );

    final sent = await repository.saveNote(note);

    if (!mounted) return;

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexão: nota será sincronizada quando houver conexão.'),
        ),
      );
    }

    Navigator.pop(context);
  }

  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final result = await repository.getCategories(user.uid);

    if (!mounted) return;

    setState(() {
      categories = result;
      selectCategory(selectedCategory);
    });
  }

  void selectCategory(String name) {
    if (name.isEmpty) {
      selectedCategory = '';
      return;
    }

    final index = categories.indexWhere(
      (category) => category.toLowerCase() == name.toLowerCase(),
    );

    if (index == -1) {
      categories.add(name);
      selectedCategory = name;
    } else {
      selectedCategory = categories[index];
    }
  }

  Future<String?> askCategoryName() {
    var name = '';

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Nome da categoria',
          ),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Criar'),
          )
        ]
      )
    );
  }

  Future<void> onCategoryChanged(String? value) async {
    if (value == null) return;

    if (value != newCategoryOption) {
      setState(() {
        selectedCategory = value;
      });
      return;
    }

    final name = await askCategoryName();

    if (name == null || name.isEmpty || !mounted) return;

    setState(() {
      selectCategory(name);
    });
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
            onPressed: saving ? null : saveNote,
            icon: saving ? 
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.0,)
              )
              : const Icon(Icons.save_rounded),
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

            const Divider(color: Color(0xFFE4DFEA)),

            if (categories.isNotEmpty)
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                underline: SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text('Sem categoria')
                  ),
                  for (final category in categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                  DropdownMenuItem(
                    value: newCategoryOption,
                    child: Text('+ Nova categoria'),
                  )
                ],
                onChanged: onCategoryChanged,
              ),

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
