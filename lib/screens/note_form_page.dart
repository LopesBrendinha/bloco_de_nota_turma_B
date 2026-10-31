import 'package:blocodenotasturmab/models/categories.dart';
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
  final titleController = TextEditingController();

  final contentController = TextEditingController();

  final repository = NoteRepository();

  String category = 'Geral';

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
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final title = titleController.text.trim();

    final content = contentController.text.trim();

    if (content.isEmpty || saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // Nota nova: o id é a hora atual em milissegundos (não repete
    // entre instalações). Edição: mantém id e data de criação.
    final oldCreatedAt = widget.note?.createdAt ?? '';

    final note = Note(
      id: widget.note?.id ?? now.millisecondsSinceEpoch,
      uid: user.uid,
      title: title,
      content: content,
      date: date,
      category: category,
      createdAt: oldCreatedAt.isEmpty ? nowIso : oldCreatedAt,
      updatedAt: nowIso,
    );

    final synced = await repository.saveNote(note, isNew: !isEditing);

    if (!mounted) return;

    if (!synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nota salva neste dispositivo, mas não foi possível '
            'enviá-la ao Firebase.',
          ),
        ),
      );
    }

    Navigator.pop(context);
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

            // Seleção da categoria da nota.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                children: noteCategories.map((item) {
                  return ChoiceChip(
                    label: Text(item),
                    selected: category == item,
                    onSelected: (_) {
                      setState(() {
                        category = item;
                      });
                    },
                  );
                }).toList(),
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