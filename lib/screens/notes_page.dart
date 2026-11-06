import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/note_repository.dart';
import '../widgets/note_card.dart';
import 'login_page.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteRepository repository = NoteRepository();

  final AuthService authService = AuthService();

  final searchController = TextEditingController();

  List<Note> notes = [];

  List<String> categories = [];

  // null = todas as categorias
  String? selectedCategory;

  // false = notas ativas, true = notas arquivadas
  bool showArchived = false;

  static const String _offlineMessage =
      'Sem conexão com o Firebase. As notas continuam salvas no aparelho '
      'e serão enviadas depois.';

  @override
  void initState() {
    super.initState();

    // Mostra primeiro o que já está no SQLite e depois sincroniza.
    loadNotes();

    syncNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> loadNotes() async {
    // Recuperamos o usuário atualmente autenticado no Firebase.
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Lê do SQLite somente as notas desse usuário, aplicando
    // pesquisa, categoria e filtro de arquivadas.
    final result = await repository.list(
      user.uid,
      archived: showArchived,
      query: searchController.text,
      category: selectedCategory,
    );

    final allCategories = await repository.categories(user.uid);

    if (!mounted) return;

    setState(() {
      notes = result;
      categories = allCategories;

      // Se a categoria escolhida não existe mais, volta para "Todas".
      if (selectedCategory != null &&
          !allCategories.contains(selectedCategory)) {
        selectedCategory = null;
      }
    });
  }

  Future<void> syncNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final ok = await repository.sync(user.uid);

    await loadNotes();

    if (!ok) showMessage(_offlineMessage);
  }

  Future<void> deleteNote(Note note) async {
    final ok = await repository.delete(note);

    await loadNotes();

    showMessage(
      ok ? 'Nota excluída.' : 'Nota excluída no aparelho. $_offlineMessage',
    );
  }

  Future<void> toggleArchive(Note note) async {
    final ok = await repository.setArchived(note, !note.archived);

    await loadNotes();

    showMessage(
      note.archived ? 'Nota desarquivada.' : 'Nota arquivada.',
    );

    if (!ok) showMessage(_offlineMessage);
  }

  Future<void> logout() async {
    await authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> openForm([Note? note]) async {
    // A tela do formulário devolve true/false: se a nuvem foi atualizada.
    final syncedToCloud = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    await loadNotes();

    if (syncedToCloud == false) showMessage(_offlineMessage);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          showArchived ? 'Notas arquivadas' : 'Minhas notas',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: showArchived ? 'Ver notas ativas' : 'Ver arquivadas',
            onPressed: () {
              setState(() => showArchived = !showArchived);
              loadNotes();
            },
            icon: Icon(
              showArchived ? Icons.notes_rounded : Icons.archive_outlined,
            ),
          ),

          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),

          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openForm(),

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
              user?.email ?? '',
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),

            const SizedBox(height: 14),

            // Pesquisa por título ou conteúdo
            TextField(
              controller: searchController,
              onChanged: (_) => loadNotes(),
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          loadNotes();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Filtro por categoria
            if (categories.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todas'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          setState(() => selectedCategory = null);
                          loadNotes();
                        },
                      ),
                    ),
                    ...categories.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: selectedCategory == c,
                          onSelected: (_) {
                            setState(() => selectedCategory = c);
                            loadNotes();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            Expanded(
              // Puxar a lista para baixo força a sincronização com o Firebase.
              child: RefreshIndicator(
                onRefresh: syncNotes,
                child: notes.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Column(
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
                                Text(
                                  searchController.text.isNotEmpty
                                      ? 'Nenhuma nota encontrada'
                                      : showArchived
                                      ? 'Nenhuma nota arquivada'
                                      : 'Nenhuma nota ainda',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Puxe para baixo para sincronizar.',
                                  style: TextStyle(color: Color(0xFF77717F)),
                                ),
                              ],
                            ),
                          ),
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
                            onTap: () => openForm(note),
                            onDelete: () => deleteNote(note),
                            onArchive: () => toggleArchive(note),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
