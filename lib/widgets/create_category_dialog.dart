import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note_category.dart';
import '../repositories/notes_repository.dart';

/// Pede o nome de uma nova categoria e a cria.
///
/// Retorna a categoria criada, ou null se o usuário cancelar.
Future<NoteCategory?> showCreateCategoryDialog(
  BuildContext context,
  NotesRepository repository,
) {
  return showDialog<NoteCategory>(
    context: context,
    builder: (_) => _CreateCategoryDialog(repository: repository),
  );
}

class _CreateCategoryDialog extends StatefulWidget {
  final NotesRepository repository;

  const _CreateCategoryDialog({required this.repository});

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  final nameController = TextEditingController();
  String? errorText;

  Future<void> create() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        errorText = 'Digite um nome.';
      });
      return;
    }

    try {
      final category = await widget.repository.createCategory(name);
      if (mounted) Navigator.pop(context, category);
    } on CategoryExistsException {
      setState(() {
        errorText = 'Já existe uma categoria com esse nome.';
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nova categoria'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          LengthLimitingTextInputFormatter(NoteCategory.maxNameLength),
        ],
        onSubmitted: (_) => create(),
        decoration: InputDecoration(
          hintText: 'Ex.: Faculdade',
          errorText: errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        TextButton(onPressed: create, child: Text('Criar')),
      ],
    );
  }
}
