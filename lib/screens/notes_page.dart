import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/auth_service.dart';
import '../widgets/note_card.dart';
import 'login_page.dart';
import 'note_form_page.dart';
import 'trash_page.dart';

class NotesPage extends StatefulWidget {
  final NoteRepository? repository;

  const NotesPage({super.key, this.repository});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NoteRepository repository = widget.repository ?? NoteRepository();
  final AuthService authService = AuthService();
  final searchController = TextEditingController();

  List<Note> notes = [];
  List<String> categories = [];
  String? selectedCategory; // null = todas
  bool syncing = false;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Mostra primeiro o que está no aparelho e depois atualiza com a nuvem.
    loadNotes().then((_) => syncNow(silent: true));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showMessage(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> loadNotes() async {
    final uid = this.uid;
    if (uid == null) return;

    final result = await repository.getNotes(
      uid,
      query: searchController.text,
      category: selectedCategory,
    );
    final cats = await repository.getCategories(uid);

    if (mounted) {
      setState(() {
        notes = result;
        categories = cats;
      });
    }
  }

  Future<void> syncNow({bool silent = false}) async {
    final uid = this.uid;
    if (uid == null || syncing) return;

    setState(() => syncing = true);
    final ok = await repository.sync(uid);
    if (!mounted) return;
    setState(() => syncing = false);
    await loadNotes();

    if (!ok) {
      showMessage('Sem conexão com a nuvem. Exibindo as notas salvas no aparelho.');
    } else if (!silent) {
      showMessage('Notas sincronizadas.');
    }
  }

  void reportSave(bool? synced) {
    if (synced == false) {
      showMessage('Salva no aparelho. Será enviada à nuvem quando houver conexão.');
    }
  }

  Future<void> moveToTrash(Note note) async {
    await repository.moveToTrash(note);
    await loadNotes();
    showMessage(
      'Nota movida para a lixeira.',
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () async {
          final trashed = (await repository.getTrash(note.uid))
              .firstWhere((n) => n.remoteId == note.remoteId);
          await repository.restore(trashed);
          await loadNotes();
        },
      ),
    );
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
    final synced = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(note: note, repository: repository),
      ),
    );
    await loadNotes();
    reportSave(synced);
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashPage(repository: repository)),
    );
    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final filtering = searchController.text.isNotEmpty || selectedCategory != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas notas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: syncing ? null : syncNow,
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
            icon: const Icon(Icons.delete_sweep_outlined),
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
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in [null, ...categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c ?? 'Todas'),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: syncNow,
                child: notes.isEmpty
                    ? _EmptyState(filtering: filtering)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return NoteCard(
                            note: note,
                            onTap: () => openForm(note),
                            onDelete: () => moveToTrash(note),
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

class _EmptyState extends StatelessWidget {
  final bool filtering;

  const _EmptyState({required this.filtering});

  @override
  Widget build(BuildContext context) {
    // ListView para o "puxar para atualizar" funcionar mesmo sem notas.
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE5FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtering ? Icons.search_off_rounded : Icons.sticky_note_2_outlined,
              size: 50,
              color: const Color(0xFF6C4AB6),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Center(
          child: Text(
            filtering ? 'Nenhuma nota encontrada' : 'Nenhuma nota ainda',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            filtering ? 'Tente outra palavra ou categoria.' : 'Crie sua primeira nota.',
            style: const TextStyle(color: Color(0xFF77717F)),
          ),
        ),
      ],
    );
  }
}
