import 'dart:math';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;
  final String uid;
  final DatabaseHelper? database;

  const NoteFormPage({super.key, this.note, required this.uid, this.database});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  late final DatabaseHelper database;
  List<String> categories = ['Estudos', 'Trabalho', 'Pessoal'];
  String category = 'Pessoal';
  bool saving = false;
  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    database = widget.database ?? DatabaseHelper.instance;
    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
      category = widget.note!.category;
      if (!categories.contains(category)) categories.add(category);
    }
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final result = await database.getCategories(widget.uid);
      if (mounted) {
        setState(() => categories = {...result, category}.toList()..sort());
      }
    } catch (_) {
      showMessage('Não foi possível carregar as categorias salvas.');
    }
  }

  void showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> addCategory() async {
    String name = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          onChanged: (value) => name = value.trim(),
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (mounted && value != null) {
      setState(() {
        final matching = categories.where(
          (item) => item.toLowerCase() == value.toLowerCase(),
        );
        category = matching.isEmpty ? value : matching.first;
        categories = {...categories, category}.toList()..sort();
      });
    }
  }

  Future<void> saveNote() async {
    if (saving) return;
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (content.isEmpty) {
      showMessage('Escreva o conteúdo da nota.');
      return;
    }
    setState(() => saving = true);
    final now = max(
      DateTime.now().microsecondsSinceEpoch,
      (widget.note?.updatedAt ?? 0) + 1,
    );
    final note = Note(
      id: widget.note?.id,
      remoteId: widget.note?.remoteId ?? Note.newRemoteId(),
      uid: widget.uid,
      title: title,
      content: content,
      category: category,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      archived: widget.note?.archived ?? false,
    );
    try {
      if (isEditing) {
        final count = await database.updateNote(note);
        if (count == 0) throw StateError('A nota foi excluída.');
      } else {
        await database.insertNote(note);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      showMessage('Não foi possível salvar. Seu texto continua no formulário.');
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
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              readOnly: saving,
              maxLength: 200,
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
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: category,
                    isExpanded: true,
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
                        : (value) {
                            if (value != null) setState(() => category = value);
                          },
                  ),
                ),
                IconButton(
                  tooltip: 'Nova categoria',
                  onPressed: saving ? null : addCategory,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE4DFEA)),
            Expanded(
              child: TextField(
                controller: contentController,
                readOnly: saving,
                maxLines: null,
                expands: true,
                maxLength: 100000,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
