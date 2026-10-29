import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/note_card.dart';
import '../widgets/sync_status_button.dart';
import 'note_form_page.dart';
import 'trash_page.dart';

class NotesPage extends StatefulWidget {
  final User user;

  const NotesPage({super.key, required this.user});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final repository = NoteRepository.instance;
  final authService = AuthService();
  final searchController = TextEditingController();
  Timer? _debounce;

  List<Note> notes = [];
  List<String> categories = [];
  String? selectedCategory; // null = todas
  NoteSort sort = NoteSort.updatedDesc;
  bool loading = true;

  String get uid => widget.user.uid;
  bool get isFiltering =>
      searchController.text.trim().isNotEmpty || selectedCategory != null;

  static const _sortLabels = {
    NoteSort.updatedDesc: 'Última atualização (recentes)',
    NoteSort.updatedAsc: 'Última atualização (antigas)',
    NoteSort.createdDesc: 'Data de criação (recentes)',
    NoteSort.createdAsc: 'Data de criação (antigas)',
    NoteSort.titleAsc: 'Título (A–Z)',
  };

  @override
  void initState() {
    super.initState();
    // Recarrega a lista sempre que uma sincronização termina, para mostrar
    // as notas que chegaram da nuvem.
    repository.changes.addListener(loadNotes);
    _start();
  }

  Future<void> _start() async {
    await repository.purgeOldTrash(uid);
    await loadNotes();
    // Ao entrar (inclusive em outra instalação), busca as notas da nuvem.
    final result = await repository.sync(uid);
    _showSyncError(result);
  }

  @override
  void dispose() {
    repository.changes.removeListener(loadNotes);
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadNotes() async {
    final results = await Future.wait([
      repository.getNotes(
        uid,
        query: searchController.text,
        category: selectedCategory,
        sort: sort,
      ),
      repository.getCategoryNames(uid),
    ]);
    if (!mounted) return;
    setState(() {
      notes = results[0] as List<Note>;
      categories = results[1] as List<String>;
      loading = false;
    });
  }

  void onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), loadNotes);
    setState(() {}); // atualiza o botão de limpar
  }

  Future<void> syncNow() async {
    final result = await repository.sync(uid);
    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notas sincronizadas.')));
    } else {
      _showSyncError(result);
    }
  }

  void _showSyncError(SyncResult result) {
    if (result.success || !mounted) return;
    final text = result.isConnectionError
        ? '${result.message} Suas notas estão salvas no aparelho e serão '
              'enviadas quando a conexão voltar.'
        : result.message!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: SnackBarAction(label: 'Tentar de novo', onPressed: syncNow),
      ),
    );
  }

  Future<void> moveToTrash(Note note) async {
    await repository.moveToTrash(note);
    await loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota movida para a lixeira.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            final trashed = (await repository.getTrash(
              uid,
            )).where((n) => n.remoteId == note.remoteId);
            if (trashed.isNotEmpty) {
              await repository.restoreFromTrash(trashed.first);
            }
            await loadNotes();
          },
        ),
      ),
    );
  }

  Future<void> logout() async {
    // Mostra o status de sincronização antes de sair, para o usuário não
    // perder alterações que ainda não chegaram à nuvem.
    final pending = repository.syncInfo.value.pending;
    if (pending > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alterações não enviadas'),
          content: Text(
            'Existem $pending alteração(ões) que ainda não foram enviadas '
            'para a nuvem. Elas continuam salvas neste aparelho e serão '
            'enviadas quando você entrar novamente com esta conta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair mesmo assim'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    repository.reset();
    await authService.logout(); // o AuthGate volta para o login
  }

  Future<void> openForm([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(user: widget.user, note: note),
      ),
    );
    await loadNotes();
  }

  Future<void> openTrash() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashPage(user: widget.user)),
    );
    await loadNotes();
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
          SyncStatusButton(onPressed: syncNow),
          PopupMenuButton<NoteSort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort_rounded),
            initialValue: sort,
            onSelected: (value) {
              setState(() => sort = value);
              loadNotes();
            },
            itemBuilder: (_) => [
              for (final entry in _sortLabels.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
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
          const SizedBox(width: 4),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              widget.user.email ?? '',
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Pesquisar no título ou conteúdo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _chip('Todas', null),
                for (final c in categories) _chip(c, c),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isFiltering && !loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                '${notes.length} resultado(s)',
                style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: syncNow,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : notes.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          onTap: () => openForm(note),
                          dateLabel: sort == NoteSort.createdDesc ||
                                  sort == NoteSort.createdAsc
                              ? 'Criada em'
                              : 'Atualizada em',
                          date: sort == NoteSort.createdDesc ||
                                  sort == NoteSort.createdAsc
                              ? note.createdAt
                              : note.updatedAt,
                          actions: [
                            IconButton(
                              tooltip: 'Mover para a lixeira',
                              onPressed: () => moveToTrash(note),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xffb45f6c),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectedCategory == value,
        onSelected: (_) {
          setState(() => selectedCategory = value);
          loadNotes();
        },
      ),
    );
  }

  Widget _emptyState() {
    // ListView para o "puxar para atualizar" funcionar mesmo com a lista vazia.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              isFiltering
                  ? Icons.search_off_rounded
                  : Icons.sticky_note_2_outlined,
              size: 50,
              color: const Color(0xFF6C4AB6),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Center(
          child: Text(
            isFiltering ? 'Nenhuma nota encontrada' : 'Nenhuma nota ainda',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            isFiltering
                ? 'Tente outra palavra ou categoria.'
                : 'Crie sua primeira nota.',
            style: const TextStyle(color: Color(0xFF77717F)),
          ),
        ),
      ],
    );
  }
}
