import 'package:flutter/material.dart';

import '../models/note_category.dart';
import '../repositories/notes_repository.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/create_category_dialog.dart';

class CategoriesPage extends StatefulWidget {
  final NotesRepository repository;

  const CategoriesPage({super.key, required this.repository});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<NoteCategory> categories = [];

  @override
  void initState() {
    super.initState();

    widget.repository.addListener(loadCategories);
    loadCategories();
  }

  Future<void> loadCategories() async {
    final result = await widget.repository.getCategories();

    if (mounted) {
      setState(() {
        categories = result;
      });
    }
  }

  Future<void> deleteCategory(NoteCategory category) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir "${category.name}"?',
      message: 'As notas desta categoria não serão apagadas.',
      confirmLabel: 'Excluir',
    );

    if (confirmed) {
      await widget.repository.deleteCategory(category.id);
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(loadCategories);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categorias',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateCategoryDialog(context, widget.repository),

        backgroundColor: const Color(0xFF6C4AB6),

        foregroundColor: Colors.white,

        icon: const Icon(Icons.add_rounded),

        label: const Text(
          'Nova categoria',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),

        itemCount: categories.length,

        itemBuilder: (context, index) {
          final category = categories[index];

          return ListTile(
            leading: const Icon(
              Icons.label_outline_rounded,
              color: Color(0xFF6C4AB6),
            ),
            title: Text(category.name),
            subtitle: category.isDefault ? const Text('Padrão') : null,
            trailing: category.isDefault
                ? null
                : IconButton(
                    tooltip: 'Excluir categoria',
                    onPressed: () => deleteCategory(category),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB45F6C),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
