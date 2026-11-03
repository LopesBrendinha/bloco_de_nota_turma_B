import 'package:blocodenotasturmab/models/category.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Diálogo para criar ou editar uma categoria. Devolve (nome, cor) ou null.
Future<(String, int)?> showCategoryDialog(
  BuildContext context, {
  NoteCategory? category,
}) {
  return showDialog<(String, int)>(
    context: context,
    builder: (_) => _CategoryDialog(category: category),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final NoteCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late int color = widget.category?.color ?? 0;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void submit() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.category == null ? 'Nova categoria' : 'Editar categoria',
        style: AppTheme.display(context, size: 22),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex.: Faculdade'),
            onSubmitted: (_) => submit(),
          ),
          const SizedBox(height: 8),
          Text('Cor do marca-texto', style: AppTheme.handwritten(context)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < CategoryPalette.colors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => color = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CategoryPalette.of(i),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: color == i
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                    child: color == i
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: GrafiteColors.ink,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            foregroundColor: Theme.of(context).colorScheme.surface,
          ),
          onPressed: submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
