import 'package:blocodenotasturmab/database/database_helper.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/services/sync_service.dart';
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
  final database = DatabaseHelper.instance;

  static const defaultCategories = ['Geral', 'Estudos', 'Trabalho', 'Pessoal'];

  List<String> categories = [...defaultCategories];
  String category = 'Geral';

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

  // Junta as categorias padrão com as que o usuário já criou.
  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final saved = await database.getCategories(user.uid);
    if (!mounted) return;

    setState(() {
      for (final c in [...saved, category]) {
        if (!categories.contains(c)) categories.add(c);
      }
    });
  }

  Future<void> newCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: Receitas'),
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

    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!categories.contains(name)) categories.add(name);
        category = name;
      });
    }
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (content.isEmpty) return;

    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final note = Note(
      id: widget.note?.id,
      // Edição mantém o ID; nota nova ganha um ID novo.
      syncId: widget.note?.syncId ?? SyncService.instance.newId(user.uid),
      uid: user.uid,
      title: title,
      content: content,
      category: category,
      date: date,
      updatedAt: now.toUtc().toIso8601String(),
      deleted: false,
      synced: false,
    );

    // 1) Sempre grava primeiro no SQLite.
    if (isEditing) {
      await database.updateNote(note);
    } else {
      await database.insertNote(note);
    }

    // 2) Depois tenta enviar ao Firestore.
    final sent = await SyncService.instance.push(note);

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    if (!sent) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Nota salva no aparelho. Não foi possível enviar ao Firebase; '
            'ela será enviada na próxima sincronização.',
          ),
        ),
      );
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setState(() => category = c),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Nova'),
                    onPressed: newCategory,
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
