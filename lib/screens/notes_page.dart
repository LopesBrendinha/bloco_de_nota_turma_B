import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/note_card.dart';
import 'login_page.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  final String uid;
  final String? email;
  final DatabaseHelper? database;
  final SyncService? syncService;

  const NotesPage({
    super.key,
    required this.uid,
    this.email,
    this.database,
    this.syncService,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  late final DatabaseHelper database;
  late final SyncService syncService;
  final searchController = TextEditingController();
  late final String uid;
  List<Note> notes = [];
  NoteOrder order = NoteOrder.updated;
  bool archived = false;
  bool syncing = false;
  bool refreshRequested = false;
  bool changing = false;
  String status = 'Carregando notas...';
  int loadNumber = 0;

  @override
  void initState() {
    super.initState();
    uid = widget.uid;
    database = widget.database ?? DatabaseHelper.instance;
    syncService = widget.syncService ?? SyncService(database: database);
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> loadNotes() async {
    final request = ++loadNumber;
    final result = await database.getNotes(
      uid,
      search: searchController.text,
      archived: archived,
      order: order,
    );
    if (mounted && request == loadNumber) setState(() => notes = result);
  }

  Future<void> refresh() async {
    if (!mounted) return;
    if (syncing) {
      refreshRequested = true;
      return;
    }
    setState(() {
      syncing = true;
      status = 'Sincronizando...';
    });
    try {
      await loadNotes();
      try {
        await syncService.synchronize(uid);
      } finally {
        // Também mostrar notas recuperadas durante uma sincronização parcial.
        await loadNotes();
      }
      final pending = await database.getPendingNotes(uid);
      if (mounted) {
        setState(
          () => status = pending.isEmpty
              ? 'Notas sincronizadas.'
              : 'Há alterações aguardando sincronização.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => status = SyncService.errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => syncing = false);
        if (refreshRequested) {
          refreshRequested = false;
          refresh();
        }
      }
    }
  }

  Future<void> filterNotes() async {
    try {
      await loadNotes();
    } catch (_) {
      showMessage('Não foi possível carregar as notas deste aparelho.');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> changeNote(Note note, {bool remove = false}) async {
    if (changing) return;
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir nota?'),
          content: const Text(
            'Esta nota será excluída dos seus aparelhos após a sincronização. Não é possível recuperar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => changing = true);
    try {
      if (remove) {
        await database.deleteNote(note);
      } else {
        await database.setArchived(note, !note.archived);
      }
      await loadNotes();
      if (mounted) {
        showMessage(
          remove
              ? 'Nota excluída neste aparelho.'
              : note.archived
              ? 'Nota desarquivada.'
              : 'Nota arquivada.',
        );
        refresh();
      }
    } catch (_) {
      showMessage('Não foi possível alterar a nota. Tente novamente.');
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> openNote([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(note: note, uid: uid, database: database),
      ),
    );
    if (!mounted) return;
    await filterNotes();
    if (mounted) refresh();
  }

  Future<void> logout() async {
    try {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      showMessage('Não foi possível sair. Tente novamente.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          archived ? 'Notas arquivadas' : 'Minhas notas',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: syncing ? null : refresh,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNote(),
        backgroundColor: const Color(0xFF6C4AB6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova nota'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.email ?? '',
              style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (_) => filterNotes(),
              decoration: const InputDecoration(
                hintText: 'Pesquisar título ou conteúdo',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Arquivadas'),
                  selected: archived,
                  onSelected: (value) {
                    setState(() => archived = value);
                    filterNotes();
                  },
                ),
                DropdownButton<NoteOrder>(
                  value: order,
                  items: const [
                    DropdownMenuItem(
                      value: NoteOrder.updated,
                      child: Text('Última atualização'),
                    ),
                    DropdownMenuItem(
                      value: NoteOrder.created,
                      child: Text('Data de criação'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => order = value);
                    filterNotes();
                  },
                ),
              ],
            ),
            if (syncing) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(status, style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Text(
                        searchController.text.trim().isNotEmpty
                            ? 'Nenhuma nota encontrada.'
                            : archived
                            ? 'Nenhuma nota arquivada.'
                            : 'Crie sua primeira nota.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          onTap: () => openNote(note),
                          onDelete: () => changeNote(note, remove: true),
                          onArchive: () => changeNote(note),
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
