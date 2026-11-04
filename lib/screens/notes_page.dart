import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_category.dart';
import '../repositories/notes_repository.dart';
import '../services/auth_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/note_card.dart';
import '../widgets/sync_status_banner.dart';
import 'categories_page.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  final NotesRepository repository;
  final AuthService authService;
  final String email;

  const NotesPage({
    super.key,
    required this.repository,
    required this.authService,
    required this.email,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  final searchController = TextEditingController();

  Timer? searchTimer;
  List<Note> notes = [];
  List<NoteCategory> categories = [];
  String? selectedCategoryId;
  bool loading = true;

  /// Número da última busca. Se o usuário digitar rápido, uma resposta
  /// antiga não substitui o resultado mais novo.
  int lastLoad = 0;

  NotesRepository get repository => widget.repository;

  bool get isFiltering =>
      searchController.text.trim().isNotEmpty || selectedCategoryId != null;

  @override
  void initState() {
    super.initState();

    // A lista recarrega quando uma alteração local ou a sincronização
    // muda os dados.
    repository.addListener(loadNotes);
    WidgetsBinding.instance.addObserver(this);

    loadNotes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar para o aplicativo, buscamos o que mudou em outros aparelhos.
    if (state == AppLifecycleState.resumed) {
      repository.syncNow();
    }
  }

  Future<void> loadNotes() async {
    final load = ++lastLoad;

    final loadedCategories = await repository.getCategories();

    // A categoria selecionada pode ter sido apagada aqui ou em outro aparelho.
    if (!loadedCategories.any((item) => item.id == selectedCategoryId)) {
      selectedCategoryId = null;
    }

    final loadedNotes = await repository.getNotes(
      query: searchController.text,
      categoryId: selectedCategoryId,
    );

    if (mounted && load == lastLoad) {
      setState(() {
        categories = loadedCategories;
        notes = loadedNotes;
        loading = false;
      });
    }
  }

  void onSearchChanged(String _) {
    // Espera uma pausa na digitação para não consultar a cada tecla.
    searchTimer?.cancel();
    searchTimer = Timer(const Duration(milliseconds: 250), loadNotes);

    // Atualiza o botão de limpar a pesquisa.
    setState(() {});
  }

  void clearSearch() {
    searchTimer?.cancel();
    searchController.clear();
    loadNotes();
  }

  void selectCategory(String? categoryId) {
    setState(() {
      selectedCategoryId = categoryId;
    });
    loadNotes();
  }

  String? categoryNameOf(Note note) {
    for (final category in categories) {
      if (category.id == note.categoryId) return category.name;
    }
    return null;
  }

  Future<void> deleteNote(Note note) async {
    final confirmed = await confirmAction(
      context,
      title: 'Excluir nota?',
      message: 'A nota será apagada deste aparelho e da nuvem.',
      confirmLabel: 'Excluir',
    );

    if (confirmed) {
      await repository.deleteNotePermanently(note.id);
    }
  }

  Future<void> logout() async {
    final pending = repository.status.pendingChanges;

    if (pending > 0) {
      final confirmed = await confirmAction(
        context,
        title: 'Sair da conta?',
        message:
            'Há alterações que ainda não chegaram à nuvem. Elas ficam guardadas '
            'neste aparelho e serão enviadas quando você entrar de novo.',
        confirmLabel: 'Sair',
      );
      if (!confirmed) return;
    }

    // O AuthGate percebe a saída e volta para a tela de login.
    await widget.authService.logout();
  }

  void openNoteForm([Note? note]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(repository: repository, note: note),
      ),
    );
  }

  void openCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoriesPage(repository: repository)),
    );
  }

  @override
  void dispose() {
    repository.removeListener(loadNotes);
    WidgetsBinding.instance.removeObserver(this);
    searchTimer?.cancel();
    searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: 'Categorias',
            onPressed: openCategories,
            icon: const Icon(Icons.label_outline_rounded),
          ),

          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),

          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNoteForm(),

        backgroundColor: const Color(0xFF6C4AB6),

        foregroundColor: Colors.white,

        icon: const Icon(Icons.add_rounded),

        label: const Text(
          'Nova nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              widget.email,
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),

            const SizedBox(height: 6),

            SyncStatusBanner(
              status: repository.status,
              onRetry: repository.syncNow,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Pesquisar no título ou no conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  categoryChip('Todas', null),
                  for (final category in categories)
                    categoryChip(category.name, category.id),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (isFiltering && !loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  notes.length == 1
                      ? '1 nota encontrada'
                      : '${notes.length} notas encontradas',
                  style: const TextStyle(
                    color: Color(0xFF77717F),
                    fontSize: 13,
                  ),
                ),
              ),

            Expanded(child: buildList()),
          ],
        ),
      ),
    );
  }

  Widget categoryChip(String label, String? categoryId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectedCategoryId == categoryId,
        onSelected: (_) => selectCategory(categoryId),
      ),
    );
  }

  Widget buildList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: repository.syncNow,

      child: notes.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 40),
                isFiltering ? buildNoResults() : buildEmptyState(),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),

              itemCount: notes.length,

              itemBuilder: (context, index) {
                final note = notes[index];

                return NoteCard(
                  note: note,
                  categoryName: categoryNameOf(note),

                  onTap: () => openNoteForm(note),

                  actions: [
                    IconButton(
                      tooltip: 'Excluir',
                      onPressed: () => deleteNote(note),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xffb45f6c),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget buildNoResults() {
    return const Column(
      children: [
        Icon(Icons.search_off_rounded, size: 50, color: Color(0xFF6C4AB6)),

        SizedBox(height: 16),

        Text(
          'Nenhuma nota encontrada',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        SizedBox(height: 8),

        Text(
          'Tente outra palavra ou outra categoria.',
          style: TextStyle(color: Color(0xFF77717F)),
        ),
      ],
    );
  }

  Widget buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,

          decoration: const BoxDecoration(
            color: Color(0xFFEDE5FA),
            shape: BoxShape.circle,
          ),

          child: const Icon(
            Icons.sticky_note_2_outlined,
            size: 50,
            color: Color(0xFF6C4AB6),
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          'Nenhuma nota ainda',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        const Text(
          'Crie sua primeira nota.',
          style: TextStyle(color: Color(0xFF77717F)),
        ),
      ],
    );
  }
}
