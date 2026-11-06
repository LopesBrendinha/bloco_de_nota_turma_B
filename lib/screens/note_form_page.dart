import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/note_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  static const String _newCategoryValue = '__nova_categoria__';
  static const List<String> _defaultCategories = [
    'Estudos',
    'Trabalho',
    'Pessoal',
  ];

  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final repository = NoteRepository();

  List<String> categories = [..._defaultCategories];

  String category = 'Pessoal';

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

  // Categorias padrão + as que o usuário já criou.
  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final saved = await repository.categories(user.uid);

    final all = <String>{..._defaultCategories, ...saved, category}.toList();

    if (mounted) {
      setState(() {
        categories = all;
      });
    }
  }

  Future<void> createCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.isEmpty) return;

    setState(() {
      if (!categories.contains(name)) {
        categories.add(name);
      }
      category = name;
    });
  }

  Future<void> saveNote() async {
    if (saving) return;

    // Pegamos o usuário atualmente autenticado.
    final user = FirebaseAuth.instance.currentUser;

    // Sem usuário não podemos salvar.
    if (user == null) return;

    final title = titleController.text.trim();

    final content = contentController.text.trim();

    // Verificamos se existe conteúdo.
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escreva algo na nota.')));
      return;
    }

    setState(() => saving = true);

    // Se estamos editando, mantém o id e o estado de arquivada;
    // se estamos criando, gera um id novo.
    final note = Note(
      id: widget.note?.id ?? repository.newId(),
      uid: user.uid,
      title: title,
      content: content,
      category: category,
      archived: widget.note?.archived ?? false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Salva no SQLite e tenta enviar ao Firestore.
    // O resultado diz se a nuvem foi atualizada.
    final syncedToCloud = await repository.save(note);

    if (mounted) {
      Navigator.pop(context, syncedToCloud);
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: DropdownButton<String>(
                value: category,
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                  const DropdownMenuItem(
                    value: _newCategoryValue,
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Nova categoria...'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  if (value == _newCategoryValue) {
                    createCategory();
                  } else {
                    setState(() => category = value);
                  }
                },
              ),
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
