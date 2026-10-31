import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note_category.dart';
import '../repositories/note_repository.dart';

/// Gerenciamento de categorias: criar, renomear, trocar a cor e excluir.
///
/// Excluir uma categoria **não** exclui as notas: elas voltam para "sem
/// categoria" e são marcadas como pendentes para que o Firestore receba o
/// novo `categoryId`.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final NoteRepository repository = NoteRepository();

  List<NoteCategory> categories = [];
  Map<String, int> counts = {};
  bool loading = true;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (uid.isEmpty) return;

    final list = await repository.getCategories(uid);
    final byCategory = await repository.countNotesByCategory(uid);

    if (!mounted) return;

    setState(() {
      categories = list;
      counts = byCategory;
      loading = false;
    });
  }

  Future<void> edit({NoteCategory? existing}) async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );

    if (result == null || uid.isEmpty) return;

    await repository.saveCategory(
      uid: uid,
      name: result.name,
      colorValue: result.colorValue,
      existing: existing,
    );

    await load();
  }

  /// Cria de uma vez as categorias sugeridas que ainda não existem.
  Future<void> addSuggested() async {
    if (uid.isEmpty) return;

    final existingNames =
        categories.map((category) => category.name.toLowerCase()).toSet();

    var index = categories.length;

    for (final name in NoteRepository.suggestedCategories) {
      if (existingNames.contains(name.toLowerCase())) continue;

      await repository.saveCategory(
        uid: uid,
        name: name,
        colorValue: NoteRepository.categoryPalette[
            index % NoteRepository.categoryPalette.length],
      );

      index++;
    }

    await load();
  }

  Future<void> delete(NoteCategory category) async {
    final total = counts[category.id] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir "${category.name}"?'),
        content: Text(
          total == 0
              ? 'A categoria será removida do aparelho e do Firebase.'
              : '$total nota(s) ficarão sem categoria. As notas não serão '
                  'excluídas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB45F6C),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await repository.deleteCategory(category);
    await load();
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
        onPressed: () => edit(),
        backgroundColor: const Color(0xFF6C4AB6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova categoria',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.label_outline_rounded,
              size: 60,
              color: Color(0xFF9A94A1),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma categoria',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Crie categorias para organizar suas notas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF77717F)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: addSuggested,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Usar categorias sugeridas'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = categories[index];
        final total = counts[category.id] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: category.color.withValues(alpha: 0.18),
              child: Icon(Icons.label_rounded, color: category.color),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$total nota(s)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () => edit(existing: category),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: () => delete(category),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFB45F6C),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryFormResult {
  const _CategoryFormResult(this.name, this.colorValue);

  final String name;
  final int colorValue;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});

  final NoteCategory? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController controller =
      TextEditingController(text: widget.existing?.name ?? '');

  late int colorValue =
      widget.existing?.colorValue ?? NoteRepository.categoryPalette.first;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final name = controller.text.trim();

    if (name.isEmpty) return;

    Navigator.pop(context, _CategoryFormResult(name, colorValue));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nova categoria' : 'Editar categoria',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex.: Estudos'),
            onSubmitted: (_) => submit(),
          ),

          const SizedBox(height: 18),

          const Text('Cor', style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            children: [
              for (final value in NoteRepository.categoryPalette)
                GestureDetector(
                  onTap: () => setState(() => colorValue = value),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorValue == value
                            ? const Color(0xFF292333)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
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
        TextButton(
          onPressed: submit,
          child: Text(widget.existing == null ? 'Criar' : 'Salvar'),
        ),
      ],
    );
  }
}
