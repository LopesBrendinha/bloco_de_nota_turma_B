import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/categories.dart';
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

  final TextEditingController searchController = TextEditingController();

  List<Note> notes = [];

  // Filtro de categoria da lista ('Todas' mostra tudo).
  String selectedCategory = 'Todas';

  // Ordenação da lista: 'criacao' ou 'atualizacao'.
  String sortBy = 'criacao';

  @override
  void initState() {
    super.initState();

    startUp();
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  // Mostra primeiro as notas locais (rápido) e depois sincroniza
  // com o Firebase e atualiza a lista.
  Future<void> startUp() async {
    await loadNotes();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final synced = await repository.syncFromCloud(user.uid);

    await loadNotes();

    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível sincronizar com o Firebase. '
            'Mostrando as notas salvas neste dispositivo.',
          ),
        ),
      );
    }
  }

  // Busca no banco local, já aplicando o texto da pesquisa.
  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final result = await repository.getNotes(
      user.uid,
      search: searchController.text,
    );

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  Future<void> deleteNote(Note note) async {
    final synced = await repository.deleteNote(note);

    await loadNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Nota excluída.'
                : 'Nota excluída neste dispositivo, mas não foi possível '
                      'removê-la do Firebase.',
          ),
        ),
      );
    }
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteFormPage()),
    );

    await loadNotes();
  }

  Future<void> openEditNote(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    await loadNotes();
  }

  // Aplica o filtro de categoria e a ordenação escolhida.
  List<Note> getVisibleNotes() {
    final filtered = selectedCategory == 'Todas'
        ? List<Note>.of(notes)
        : notes.where((n) => n.category == selectedCategory).toList();

    filtered.sort((a, b) {
      if (sortBy == 'atualizacao') {
        final cmp = b.updatedAt.compareTo(a.updatedAt);

        if (cmp != 0) return cmp;
      }

      // Criação (ou desempate): o id é a hora de criação.
      return b.id!.compareTo(a.id!);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final hasSearch = searchController.text.trim().isNotEmpty;

    final visibleNotes = getVisibleNotes();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
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

            const SizedBox(height: 14),

            // Campo de pesquisa (título ou conteúdo).
            TextField(
              controller: searchController,
              onChanged: (_) => loadNotes(),
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: hasSearch
                    ? IconButton(
                        tooltip: 'Limpar pesquisa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          loadNotes();
                        },
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 14),

            // Filtro por categoria.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todas', ...noteCategories].map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: selectedCategory == item,
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = item;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Ordenação por data.
            Row(
              children: [
                const Icon(
                  Icons.sort_rounded,
                  size: 18,
                  color: Color(0xFF77717F),
                ),

                const SizedBox(width: 8),

                const Text(
                  'Ordenar por:',
                  style: TextStyle(color: Color(0xFF77717F), fontSize: 13),
                ),

                const SizedBox(width: 8),

                ChoiceChip(
                  label: const Text('Criação'),
                  selected: sortBy == 'criacao',
                  onSelected: (_) {
                    setState(() {
                      sortBy = 'criacao';
                    });
                  },
                ),

                const SizedBox(width: 8),

                ChoiceChip(
                  label: const Text('Atualização'),
                  selected: sortBy == 'atualizacao',
                  onSelected: (_) {
                    setState(() {
                      sortBy = 'atualizacao';
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (visibleNotes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

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
                        hasSearch
                            ? 'Nenhuma nota encontrada'
                            : (notes.isEmpty
                                  ? 'Nenhuma nota ainda'
                                  : 'Nenhuma nota nesta categoria'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        hasSearch
                            ? 'Tente outro termo ou outra categoria.'
                            : 'Crie sua primeira nota.',
                        style: const TextStyle(color: Color(0xFF77717F)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: visibleNotes.length,

                  itemBuilder: (context, index) {
                    final note = visibleNotes[index];

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