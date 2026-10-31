import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../repositories/note_repository.dart';
import '../utils/app_date_format.dart';

/// Formulário de criação e edição de nota.
///
/// Devolve `true` via `Navigator.pop` quando algo foi gravado, para que a
/// listagem saiba que precisa recarregar.
class NoteFormPage extends StatefulWidget {
  const NoteFormPage({super.key, this.note});

  final Note? note;

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final NoteRepository repository = NoteRepository();

  List<NoteCategory> categories = [];
  String? selectedCategoryId;

  bool saving = false;

  bool get isEditing => widget.note != null;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
      selectedCategoryId = widget.note!.categoryId;
    }

    loadCategories();
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();

    super.dispose();
  }

  Future<void> loadCategories() async {
    if (uid.isEmpty) return;

    final result = await repository.getCategories(uid);

    if (!mounted) return;

    setState(() {
      categories = result;

      // A categoria da nota pode ter sido excluída em outro aparelho.
      final exists = result.any((item) => item.id == selectedCategoryId);
      if (!exists) selectedCategoryId = null;
    });
  }

  Future<void> saveNote() async {
    if (uid.isEmpty) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      _showSnack('Escreva um título ou um conteúdo antes de salvar.');
      return;
    }

    setState(() => saving = true);

    final outcome = await repository.saveNote(
      uid: uid,
      title: title,
      content: content,
      categoryId: selectedCategoryId,
      existing: widget.note,
    );

    if (!mounted) return;

    setState(() => saving = false);

    // A nota já está no SQLite. Se a nuvem falhou, avisamos sem bloquear.
    if (!outcome.isSynced) {
      _showSnack(outcome.message ?? 'Nota salva apenas no aparelho.');
    }

    Navigator.pop(context, true);
  }

  /// Cria uma categoria sem sair do formulário.
  Future<void> createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );

    if (name == null || name.trim().isEmpty || uid.isEmpty) return;

    final color = NoteRepository
        .categoryPalette[categories.length % NoteRepository.categoryPalette.length];

    await repository.saveCategory(uid: uid, name: name.trim(), colorValue: color);

    await loadCategories();

    if (!mounted) return;

    final created = categories.where((item) => item.name == name.trim());

    if (created.isNotEmpty) {
      setState(() => selectedCategoryId = created.first.id);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
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
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Salvar',
              onPressed: saveNote,
              icon: const Icon(Icons.check_rounded),
            ),

          const SizedBox(width: 8),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

            const SizedBox(height: 6),

            _CategoryPicker(
              categories: categories,
              selectedId: selectedCategoryId,
              onSelected: (id) => setState(() => selectedCategoryId = id),
              onCreate: createCategory,
            ),

            if (isEditing) ...[
              const SizedBox(height: 10),
              Text(
                'Criada em ${AppDateFormat.short(widget.note!.createdAt)} · '
                'atualizada ${AppDateFormat.friendly(widget.note!.updatedAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9A94A1)),
              ),
            ],

            const SizedBox(height: 10),

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

/// Chips para escolher a categoria da nota.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onCreate,
  });

  final List<NoteCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Sem categoria'),
          selected: selectedId == null,
          onSelected: (_) => onSelected(null),
        ),

        for (final category in categories)
          ChoiceChip(
            label: Text(category.name),
            selected: selectedId == category.id,
            selectedColor: category.color.withValues(alpha: 0.2),
            onSelected: (_) => onSelected(category.id),
          ),

        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nova'),
          onPressed: onCreate,
        ),
      ],
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Ex.: Estudos'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
