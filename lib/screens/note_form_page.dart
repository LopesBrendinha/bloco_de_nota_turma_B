

import 'package:blocodenotasturmab/database/database_helper.dart';
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

  final database = DatabaseHelper.instance;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;

      contentController.text = widget.note!.content;
    }
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
      uid: user.uid,
      title: title,
      content: content,
      date: date,
    );

    // Verificamos se estamos criando
    // ou editando uma nota.
    if (isEditing) {
      // UPDATE
      await database.updateNote(note);
    } else {
      // INSERT
      await database.insertNote(note);
    }

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
