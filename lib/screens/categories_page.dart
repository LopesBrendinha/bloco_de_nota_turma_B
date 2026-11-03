import 'package:blocodenotasturmab/controllers/notes_controller.dart';
import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/widgets/category_dialog.dart';
import 'package:flutter/material.dart';

/// Gerencia as categorias do usuário: criar, renomear, trocar a cor e excluir.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.controller});

  final NotesController controller;

  Future<void> edit(BuildContext context, [NoteCategory? category]) async {
    final result = await showCategoryDialog(context, category: category);
    if (result == null) return;
    await controller.saveCategory(
      existing: category,
      name: result.$1,
      color: result.$2,
    );
  }

  Future<void> delete(BuildContext context, NoteCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir “${category.name}”?'),
        content: const Text(
          'As notas desta categoria não serão apagadas; elas ficam sem categoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: GrafiteColors.eraser),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) await controller.deleteCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova categoria',
        onPressed: () => edit(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final categories = controller.categories;
          if (categories.isEmpty) {
            return Center(
              child: Text(
                'nenhuma categoria ainda',
                style: AppTheme.handwritten(context, size: 22),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                onTap: () => edit(context, category),
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CategoryPalette.of(category.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: IconButton(
                  tooltip: 'Excluir',
                  onPressed: () => delete(context, category),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: GrafiteColors.eraser,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
