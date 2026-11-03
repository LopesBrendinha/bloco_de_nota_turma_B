import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/note_card.dart';
import 'login_page.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseHelper database = DatabaseHelper.instance;

  final AuthService authService = AuthService();

  final SyncService syncService = SyncService();

  List<Note> notes = [];

  // true enquanto a sincronização com a nuvem está em andamento.
  bool syncing = false;

  // Pesquisa e filtro. A busca roda no SQLite, que após a sincronização
  // tem uma cópia de todas as notas do usuário (inclusive as da nuvem).
  final TextEditingController searchController = TextEditingController();

  String query = '';

  // null significa "Todas as categorias".
  String? selectedCategory;

  List<String> categories = [];

  bool get isFiltering => query.trim().isNotEmpty || selectedCategory != null;

  @override
  void initState() {
    super.initState();

    start();
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  Future<void> start() async {
    // Primeiro mostramos o que já existe no aparelho (rápido e
    // funciona sem internet) e só depois sincronizamos com a nuvem.
    await loadNotes();
    await syncNotes();
  }

  Future<void> syncNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || syncing) return;

    setState(() => syncing = true);

    final report = await syncService.sync(user.uid);

    if (!mounted) return;

    setState(() => syncing = false);

    // A nuvem pode ter trazido notas novas: recarregamos a lista.
    await loadNotes();

    if (!report.success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(report.message)));
    }
  }

  Future<void> loadNotes() async {
    // Recuperamos o usuário atualmente
    // autenticado no Firebase.
    final user = FirebaseAuth.instance.currentUser;

    // Se não houver usuário,
    // não podemos buscar as notas.
    if (user == null) return;

    // As categorias alimentam os chips de filtro.
    await database.ensureDefaultCategories(user.uid);

    final categoryList = await database.getCategories(user.uid);

    // Enviamos o UID, o texto da pesquisa e a categoria escolhida.
    //
    // O banco irá buscar somente as notas desse usuário que combinam
    // com o título ou o conteúdo digitado e com a categoria.
    final result = await database.getNotes(
      user.uid,
      query: query,
      category: selectedCategory,
    );

    if (mounted) {
      // Atualizamos a lista utilizada
      // pela interface.
      setState(() {
        categories = categoryList;
        notes = result;
      });
    }
  }

  void clearSearch() {
    searchController.clear();

    query = '';

    loadNotes();
  }

  Future<void> deleteNote(Note note) async {
    // A nota não é apagada: recebe a data de exclusão (deletedAt) e vai
    // para a lixeira. Como é uma alteração como outra qualquer, ela
    // também é sincronizada com a nuvem. A tela da lixeira, para
    // restaurar ou excluir de vez, vem na etapa seguinte.
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.upsertNote(
      note.copyWith(deletedAt: now, updatedAt: now, synced: false),
    );

    // Depois de excluir,
    // buscamos novamente as notas.
    await loadNotes();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nota movida para a lixeira.')));
    }

    syncNotes();
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

  Future<void> openNewNote() async {
    // Abre a tela responsável pelo formulário.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteFormPage()),
    );

    // Quando o usuário voltar para essa página,
    // buscamos novamente as notas e enviamos a nova à nuvem.
    await loadNotes();
    syncNotes();
  }

  Future<void> openEditNote(Note note) async {
    // Passamos a nota selecionada
    // para a tela de edição.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    // Quando retornar da edição,
    // atualizamos a lista e enviamos a alteração à nuvem.
    await loadNotes();
    syncNotes();
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
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: syncing ? null : () => syncNotes(),
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
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
        onPressed: openNewNote,

        backgroundColor: const Color(0xFF6C4AB6),

        foregroundColor: Colors.white,

        icon: const Icon(Icons.add_rounded),

        label: const Text(
          'Nova nota',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              user?.email ?? '',
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),

            const SizedBox(height: 16),

            // Campo de pesquisa por título ou conteúdo.
            TextField(
              controller: searchController,

              onChanged: (value) {
                query = value;

                loadNotes();
              },

              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Filtro por categoria.
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
                        selectedCategory = null;

                        loadNotes();
                      },
                    ),
                  ),

                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),

                      child: ChoiceChip(
                        label: Text(category),
                        selected: selectedCategory == category,
                        onSelected: (_) {
                          selectedCategory = category;

                          loadNotes();
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (notes.isEmpty)
              Expanded(
                // O SingleChildScrollView evita faixa de erro de layout
                // quando o teclado da pesquisa reduz o espaço da tela.
                child: Center(
                  child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Container(
                        width: 100,
                        height: 100,

                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE5FA),
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
                        isFiltering ? 'Nenhum resultado' : 'Nenhuma nota ainda',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        isFiltering
                            ? 'Tente outro termo ou outra categoria.'
                            : 'Crie sua primeira nota.',
                        style: const TextStyle(color: Color(0xFF77717F)),
                      ),
                    ],
                  ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: notes.length,

                  itemBuilder: (context, index) {
                    final note = notes[index];

                    return NoteCard(
                      note: note,

                      onTap: () => openEditNote(note),

                      onDelete: () => deleteNote(note),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}