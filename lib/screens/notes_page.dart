import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/note_card.dart';
import 'login_page.dart';
import 'note_form_page.dart';
import 'trash_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseHelper database = DatabaseHelper.instance;
  final AuthService authService = AuthService();
  final searchController = TextEditingController();

  List<Note> notes = [];
  List<String> categories = [];
  String? selectedCategory; // null = todas
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    loadNotes();
    syncNow(); // ao entrar, envia pendências e baixa as notas da nuvem
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cats = await database.getCategories(user.uid);
    if (selectedCategory != null && !cats.contains(selectedCategory)) {
      selectedCategory = null;
    }

    final result = await database.getNotes(
      user.uid,
      query: searchController.text,
      category: selectedCategory,
    );

    if (mounted) {
      setState(() {
        notes = result;
        categories = cats;
      });
    }
  }

  Future<void> syncNow({bool manual = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => syncing = true);
    final error = await SyncService.instance.syncAll(user.uid);
    if (!mounted) return;

    setState(() => syncing = false);
    await loadNotes();

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else if (manual) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notas sincronizadas.')));
    }
  }

  // Exclusão "suave": a nota vai para a lixeira e pode ser recuperada.
  Future<void> moveToTrash(Note note) async {
    final trashed = note.copyWith(
      deleted: true,
      synced: false,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await database.updateNote(trashed);
    final sent = await SyncService.instance.push(trashed);
    await loadNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Nota movida para a lixeira.'
                : 'Nota movida para a lixeira (ainda não enviada ao Firebase).',
          ),
        ),
      );
    }
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );
    await loadNotes();
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
            onPressed: syncing ? null : () => syncNow(manual: true),
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Lixeira',
            onPressed: openTrash,
            icon: const Icon(Icons.delete_outline_rounded),
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
            const SizedBox(height: 14),

            // Pesquisa por título ou conteúdo.
            TextField(
              controller: searchController,
              onChanged: (_) => loadNotes(),
              decoration: InputDecoration(
                hintText: 'Pesquisar por título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          loadNotes();
                        },
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
                        setState(() => selectedCategory = null);
                        loadNotes();
                      },
                    ),
                  ),
                  for (final c in categories)
                    Padding(
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
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (notes.isEmpty)
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
                        searchController.text.isNotEmpty ||
                                selectedCategory != null
                            ? 'Nenhuma nota encontrada'
                            : 'Nenhuma nota ainda',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6, top: 4),
                          child: Text(
                            note.category,
                            style: const TextStyle(
                              color: Color(0xFF6C4AB6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        NoteCard(
                          note: note,
                          onTap: () => openEditNote(note),
                          onDelete: () => moveToTrash(note),
                        ),
                      ],
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
