import 'package:blocodenotasturmab/controllers/notes_controller.dart';
import 'package:blocodenotasturmab/models/note.dart';
import 'package:blocodenotasturmab/models/note_sort.dart';
import 'package:blocodenotasturmab/screens/categories_page.dart';
import 'package:blocodenotasturmab/screens/note_form_page.dart';
import 'package:blocodenotasturmab/services/auth_service.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:blocodenotasturmab/utils/date_utils.dart';
import 'package:blocodenotasturmab/widgets/category_dialog.dart';
import 'package:blocodenotasturmab/widgets/grafite_logo.dart';
import 'package:blocodenotasturmab/widgets/note_card.dart';
import 'package:blocodenotasturmab/widgets/sort_sheet.dart';
import 'package:blocodenotasturmab/widgets/sync_badge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.user});

  final User user;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesController controller = NotesController(uid: widget.user.uid);
  final AuthService authService = AuthService();
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.init();
  }

  @override
  void dispose() {
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> openNote([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(controller: controller, note: note),
      ),
    );
  }

  Future<void> deleteNote(Note note) async {
    await controller.deleteNote(note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '“${note.title.isEmpty ? 'Sem título' : note.title}” foi apagada',
        ),
      ),
    );
  }

  Future<void> chooseSort() async {
    final sort = await showSortSheet(context, controller.sort);
    if (sort != null) await controller.setSort(sort);
  }

  Future<void> createCategory() async {
    final result = await showCategoryDialog(context);
    if (result == null) return;
    final category = await controller.saveCategory(
      name: result.$1,
      color: result.$2,
    );
    await controller.setCategory(category.id);
  }

  /// Antes de sair tenta enviar o que falta; se não der, avisa o usuário.
  Future<void> logout() async {
    await controller.syncNow();
    final pending = controller.syncState.value.pending;
    if (pending > 0 && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair mesmo assim?'),
          content: Text(
            '$pending ${pending == 1 ? 'alteração ainda não foi enviada' : 'alterações ainda não foram enviadas'} '
            'para a nuvem. Elas continuam salvas neste aparelho e serão enviadas '
            'quando você entrar de novo com a mesma conta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const GrafiteLogo(size: 28),
            actions: [
              SyncBadge(
                state: controller.syncState,
                onSync: controller.syncNow,
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu',
                onSelected: (value) {
                  if (value == 'categories') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriesPage(controller: controller),
                      ),
                    );
                  } else if (value == 'logout') {
                    logout();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'categories',
                    child: ListTile(
                      leading: Icon(Icons.label_outline_rounded),
                      title: Text('Categorias'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sair'),
                      subtitle: Text(widget.user.email ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openNote(),
            icon: const Icon(Icons.edit_rounded),
            label: const Text(
              'Nova nota',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: RefreshIndicator(
            color: Theme.of(context).colorScheme.onSurface,
            onRefresh: controller.syncNow,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                ..._buildBody(context),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) {
              controller.setQuery(value);
              setState(() {});
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Pesquisar no título ou no conteúdo',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        controller.setQuery('');
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: controller.categoryId == null,
                  onTap: () => controller.setCategory(null),
                ),
                for (final category in controller.categories)
                  _FilterChip(
                    label: category.name,
                    color: CategoryPalette.of(category.color),
                    selected: controller.categoryId == category.id,
                    onTap: () => controller.setCategory(category.id),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Categoria'),
                    onPressed: createCategory,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: controller.isSearching
                    ? Text(
                        '${controller.notes.length} '
                        '${controller.notes.length == 1 ? 'resultado' : 'resultados'} '
                        'para “${controller.query.trim()}”',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      )
                    : Text(
                        '${controller.notes.length} '
                        '${controller.notes.length == 1 ? 'nota' : 'notas'}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
              ),
              TextButton.icon(
                onPressed: chooseSort,
                icon: Icon(
                  controller.sort.newestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18,
                ),
                label: Text(
                  controller.sort.field == SortField.updated
                      ? 'Atualização'
                      : 'Criação',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    if (controller.loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (controller.notes.isEmpty) {
      final filtered = controller.isSearching || controller.categoryId != null;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            title: filtered ? 'Nada encontrado' : 'Página em branco',
            subtitle: filtered
                ? 'tente outra palavra ou outra categoria'
                : 'toque em “Nova nota” e comece a rabiscar',
          ),
        ),
      ];
    }

    // Lista agrupada pela data usada na ordenação (funcionalidade adicional).
    final items = <Object>[];
    String? lastLabel;
    for (final note in controller.notes) {
      final date = controller.sort.field == SortField.created
          ? note.createdAt
          : note.updatedAt;
      final label = dateGroupLabel(date);
      if (label != lastLabel) {
        items.add(label);
        lastLabel = label;
      }
      items.add(note);
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  item,
                  style: AppTheme.handwritten(context, size: 22),
                ),
              );
            }
            final note = item as Note;
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              category: controller.categoryOf(note.categoryId),
              query: controller.query,
              dateField: controller.sort.field,
              onTap: () => openNote(note),
              onDelete: () => deleteNote(note),
            );
          },
        ),
      ),
    ];
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: color ?? GrafiteColors.highlighter,
        labelStyle: TextStyle(
          color: selected
              ? GrafiteColors.ink
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        avatar: color == null || selected
            ? null
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: -0.12,
            child: Icon(
              Icons.edit_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppTheme.display(context, size: 24)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.handwritten(context, size: 21),
          ),
        ],
      ),
    );
  }
}
