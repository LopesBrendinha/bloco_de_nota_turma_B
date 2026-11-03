import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final database = DatabaseHelper.instance;

  // Categorias disponíveis para o usuário e a que está escolhida na nota.
  List<String> categories = [];

  String selectedCategory = 'Geral';

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;

      selectedCategory = widget.note!.category;
    }

    loadCategories();
  }

  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await database.ensureDefaultCategories(user.uid);

    final result = await database.getCategories(user.uid);

    // Se a categoria da nota não estiver na lista (por exemplo, veio
    // da nuvem), ela é incluída para continuar aparecendo escolhida.
    if (!result.contains(selectedCategory)) {
      result.add(selectedCategory);
    }

    if (mounted) {
      setState(() {
        categories = result;
      });
    }
  }

  Future<void> addCategory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),

        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    await database.insertCategory(user.uid, name);

    // A nova categoria já fica escolhida para esta nota.
    selectedCategory = name;

    await loadCategories();
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

    // Momento da alteração, em milissegundos.
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Editando: mantemos o ID e a data de criação e atualizamos o resto.
    // Criando: geramos um UUID novo, que será o mesmo ID no Firestore.
    //
    // synced = false marca que a nota ainda precisa ser enviada à nuvem.
    final note = isEditing
        ? widget.note!.copyWith(
            title: title,
            content: content,
            category: selectedCategory,
            updatedAt: nowMs,
            synced: false,
          )
        : Note(
            id: const Uuid().v4(),
            uid: user.uid,
            title: title,
            content: content,
            category: selectedCategory,
            createdAt: nowMs,
            updatedAt: nowMs,
          );

    // O upsert cria a nota nova ou substitui a existente.
    await database.upsertNote(note);

    // Depois de salvar,
    // voltamos para a tela anterior.
    if (mounted) {
      Navigator.pop(context);
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
            onPressed: saveNote,
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

            // Escolha da categoria: um chip por categoria e o chip
            // "Nova" para criar uma categoria própria.
            SizedBox(
              height: 48,

              child: ListView(
                scrollDirection: Axis.horizontal,

                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),

                      child: ChoiceChip(
                        label: Text(category),
                        selected: category == selectedCategory,
                        onSelected: (_) {
                          setState(() => selectedCategory = category);
                        },
                      ),
                    ),

                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova'),
                    onPressed: addCategory,
                  ),
                ],
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