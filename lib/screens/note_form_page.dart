import 'package:blocodenotasturmab/controllers/notes_controller.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:blocodenotasturmab/widgets/category_dialog.dart';
import 'package:blocodenotasturmab/widgets/ruled_paper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteFormPage extends StatefulWidget {
  const NoteFormPage({super.key, required this.controller, this.note});

  final NotesController controller;
  final Note? note;

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  static const _fontSize = 17.0;
  static const _lineHeight = 1.6;

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  /// Versão salva mais recente (null enquanto a nota nova não foi gravada).
  Note? saved;
  String? categoryId;

  NotesController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    saved = widget.note;
    if (saved != null) {
      titleController.text = saved!.title;
      contentController.text = saved!.content;
      categoryId = saved!.categoryId;
    } else {
      // Nota nova criada com um filtro ativo já nasce naquela categoria.
      categoryId = controller.categoryId;
    }
  }

  bool get hasChanges {
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (saved == null) return title.isNotEmpty || content.isNotEmpty;
    return title != saved!.title ||
        content != saved!.content ||
        categoryId != saved!.categoryId;
  }

  /// Salva no SQLite (e agenda o envio ao Firestore) se algo mudou.
  Future<void> save() async {
    if (!hasChanges) return;
    saved = await controller.saveNote(
      existing: saved,
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      categoryId: categoryId,
    );
  }

  Future<void> saveAndClose() async {
    await save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> delete() async {
    final note = saved;
    if (note == null) {
      Navigator.pop(context);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar nota?'),
        content: const Text('A nota será removida deste aparelho e da nuvem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: GrafiteColors.eraser),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await controller.deleteNote(note);
    if (mounted) Navigator.pop(context);
  }

  Future<void> createCategory() async {
    final result = await showCategoryDialog(context);
    if (result == null) return;
    final category = await controller.saveCategory(
      name: result.$1,
      color: result.$2,
    );
    setState(() => categoryId = category.id);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = saved;

    // Voltar (botão ou gesto) também salva: não existe "perdi o que escrevi".
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (note != null)
              IconButton(
                tooltip: 'Apagar',
                onPressed: delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            IconButton(
              tooltip: 'Salvar',
              onPressed: saveAndClose,
              icon: const Icon(Icons.check_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
            children: [
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryOption(
                      label: 'Sem categoria',
                      selected: categoryId == null,
                      onTap: () => setState(() => categoryId = null),
                    ),
                    for (final category in controller.categories)
                      _CategoryOption(
                        label: category.name,
                        color: CategoryPalette.of(category.color),
                        selected: categoryId == category.id,
                        onTap: () => setState(() => categoryId = category.id),
                      ),
                    IconButton(
                      tooltip: 'Nova categoria',
                      onPressed: createCategory,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Título',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  'criada em ${formatDateTime(note.createdAt)} · '
                  'editada em ${formatDateTime(note.updatedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              RuledPaper(
                lineHeight: _fontSize * _lineHeight,
                child: TextField(
                  controller: contentController,
                  maxLines: null,
                  minLines: 18,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: _lineHeight,
                    color: colors.onSurface,
                  ),
                  strutStyle: const StrutStyle(
                    fontSize: _fontSize,
                    height: _lineHeight,
                    forceStrutHeight: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Comece a escrever…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.only(left: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: color ?? colors.outline,
        labelStyle: TextStyle(
          color: selected && color != null
              ? GrafiteColors.ink
              : colors.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
