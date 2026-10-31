import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../models/note_sort.dart';
import '../repositories/note_repository.dart';
import '../repositories/sync_outcome.dart';
import '../services/auth_service.dart';
import '../widgets/note_card.dart';
import '../widgets/sync_banner.dart';
import 'categories_page.dart';
import 'note_form_page.dart';
import 'trash_page.dart';

/// Tela principal: lista, pesquisa, filtra por categoria e ordena as notas.
///
/// Todo o acesso a dados passa pelo [NoteRepository]; esta classe só cuida
/// de estado de interface.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteRepository repository = NoteRepository();
  final AuthService authService = AuthService();

  final searchController = TextEditingController();

  /// Evita uma consulta ao SQLite a cada tecla digitada na pesquisa.
  Timer? searchDebounce;

  List<Note> notes = [];
  List<NoteCategory> categories = [];
  Map<String, int> notesByCategory = {};

  String? selectedCategoryId;
  NoteSort sort = NoteSort.updatedDesc;

  int trashCount = 0;

  bool loading = true;
  bool syncing = false;
  SyncOutcome? lastSync;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();

    // Primeiro mostramos o que já está no SQLite (instantâneo) e só depois
    // buscamos a nuvem. Assim a tela nunca fica em branco esperando a rede.
    load().then((_) => synchronize());
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();

    super.dispose();
  }

  /// Recarrega a tela inteira a partir do banco local.
  Future<void> load() async {
    if (uid.isEmpty) return;

    final results = await Future.wait([
      repository.getNotes(
        uid: uid,
        categoryId: selectedCategoryId,
        query: searchController.text,
        sort: sort,
      ),
      repository.getCategories(uid),
      repository.countNotesByCategory(uid),
      repository.countTrashedNotes(uid),
    ]);

    if (!mounted) return;

    setState(() {
      notes = results[0] as List<Note>;
      categories = results[1] as List<NoteCategory>;
      notesByCategory = results[2] as Map<String, int>;
      trashCount = results[3] as int;
      loading = false;
    });
  }

  /// Envia a fila local e baixa as notas da nuvem.
  Future<void> synchronize() async {
    if (uid.isEmpty) return;

    setState(() => syncing = true);

    final outcome = await repository.synchronize(uid);

    if (!mounted) return;

    setState(() {
      syncing = false;
      lastSync = outcome;
    });

    await load();
  }

  void onSearchChanged(String _) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 250), load);
  }

  Future<void> openNote([Note? note]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    if (changed == true) await load();
  }

  Future<void> moveToTrash(Note note) async {
    final outcome = await repository.moveToTrash(note);

    await load();

    if (!mounted) return;

    _showSnack(
      outcome.isSynced
          ? 'Nota movida para a lixeira.'
          : 'Nota movida para a lixeira (envio pendente).',
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () async {
          await repository.restoreFromTrash(note);
          await load();
        },
      ),
    );
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );

    await load();
  }

  Future<void> openCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesPage()),
    );

    // Uma categoria pode ter sido excluída enquanto era o filtro ativo.
    final stillExists =
        categories.any((category) => category.id == selectedCategoryId);

    if (!stillExists) selectedCategoryId = null;

    await load();
  }

  Future<void> logout() async {
    await authService.logout();
    // O AuthGate em main.dart devolve o usuário para a tela de login.
  }

  void _showSnack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<NoteSort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.swap_vert_rounded),
            initialValue: sort,
            onSelected: (value) {
              setState(() => sort = value);
              load();
            },
            itemBuilder: (_) => NoteSort.values
                .map(
                  (option) => PopupMenuItem(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
          ),

          IconButton(
            tooltip: 'Categorias',
            onPressed: openCategories,
            icon: const Icon(Icons.label_outline_rounded),
          ),

          IconButton(
            tooltip: 'Lixeira',
            onPressed: openTrash,
            icon: Badge(
              isLabelVisible: trashCount > 0,
              label: Text('$trashCount'),
              child: const Icon(Icons.delete_outline_rounded),
            ),
          ),

          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),

          const SizedBox(width: 4),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNote(),
        backgroundColor: const Color(0xFF6C4AB6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nova nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
              ),

              const SizedBox(height: 14),

              SyncBanner(
                outcome: lastSync,
                isSyncing: syncing,
                onRetry: synchronize,
              ),

              _SearchField(
                controller: searchController,
                onChanged: onSearchChanged,
                onClear: () {
                  searchController.clear();
                  load();
                },
              ),

              const SizedBox(height: 12),

              _CategoryFilter(
                categories: categories,
                counts: notesByCategory,
                selectedId: selectedCategoryId,
                onSelected: (id) {
                  setState(() => selectedCategoryId = id);
                  load();
                },
              ),

              const SizedBox(height: 6),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: synchronize,
                  child: _buildList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notes.isEmpty) {
      final isFiltering =
          searchController.text.trim().isNotEmpty || selectedCategoryId != null;

      return ListView(
        // Precisa rolar mesmo vazio para o "arraste para atualizar" funcionar.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          _EmptyState(
            icon: isFiltering
                ? Icons.search_off_rounded
                : Icons.sticky_note_2_outlined,
            title: isFiltering
                ? 'Nenhum resultado'
                : 'Nenhuma nota ainda',
            subtitle: isFiltering
                ? 'Tente outro termo ou remova o filtro de categoria.'
                : 'Crie sua primeira nota.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 90),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];

        return NoteCard(
          note: note,
          category: _categoryOf(note),
          onTap: () => openNote(note),
          trailing: IconButton(
            tooltip: 'Mover para a lixeira',
            onPressed: () => moveToTrash(note),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFB45F6C),
            ),
          ),
        );
      },
    );
  }

  NoteCategory? _categoryOf(Note note) {
    if (note.categoryId == null) return null;

    for (final category in categories) {
      if (category.id == note.categoryId) return category;
    }

    return null;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Pesquisar por título ou conteúdo',
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 20,
        ),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();

            return IconButton(
              tooltip: 'Limpar pesquisa',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            );
          },
        ),
      ),
    );
  }
}

/// Linha de chips para filtrar por categoria.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.counts,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NoteCategory> categories;
  final Map<String, int> counts;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),

          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('${category.name} (${counts[category.id] ?? 0})'),
              selected: selectedId == category.id,
              selectedColor: category.color.withValues(alpha: 0.2),
              onSelected: (_) => onSelected(category.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE5FA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: const Color(0xFF6C4AB6)),
        ),

        const SizedBox(height: 25),

        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF77717F)),
        ),
      ],
    );
  }
}
