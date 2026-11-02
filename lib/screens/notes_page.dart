import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';
import '../widgets/note_card.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with WidgetsBindingObserver {
  final database = DatabaseHelper.instance;
  final searchController = TextEditingController();
  late final String uid;
  late final SyncService syncService;
  List<Note> notes = [];
  List<String> categories = ['Estudos', 'Pessoal', 'Trabalho'];
  String? category;
  String? localError;
  bool archived = false;
  bool byCreation = false;
  bool loading = true;
  int loadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    uid = FirebaseAuth.instance.currentUser!.uid;
    syncService = SyncService(
      database: database,
      cloud: FirestoreService(),
      uid: uid,
      sessionIsActive: () => FirebaseAuth.instance.currentUser?.uid == uid,
    );
    syncService.addListener(onSyncChanged);
    searchController.addListener(loadNotes);
    unawaited(loadNotes());
    syncService.start();
  }

  void onSyncChanged() {
    if (!mounted) return;
    setState(() {});
    if (!syncService.syncing) unawaited(loadNotes());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncService.sync());
  }

  Future<void> loadNotes() async {
    final version = ++loadVersion;
    try {
      final options = await database.getCategories(uid);
      final selected = options.contains(category) ? category : null;
      final result = await database.getNotes(
        uid,
        query: searchController.text,
        category: selected,
        archived: archived,
        byCreation: byCreation,
      );
      if (mounted && version == loadVersion) {
        setState(() {
          notes = result;
          categories = options;
          category = selected;
          loading = false;
          localError = null;
        });
      }
    } catch (_) {
      if (mounted && version == loadVersion) {
        setState(() {
          loading = false;
          localError = 'Não foi possível abrir as notas deste aparelho.';
        });
      }
    }
  }

  Future<void> openNote([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(note: note, categories: categories),
      ),
    );
    if (!mounted) return;
    await loadNotes();
    unawaited(syncService.sync());
  }

  Future<void> changeNote(Note note, {bool delete = false}) async {
    if (delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir nota?'),
          content: const Text(
            'O conteúdo será removido deste aparelho e do Firebase na próxima sincronização.',
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
    try {
      await database.saveNote(
        note.copyWith(
          title: delete ? '' : null,
          content: delete ? '' : null,
          category: delete ? 'Pessoal' : null,
          archived: delete ? false : !note.archived,
          deleted: delete,
          updatedAt: max(
            DateTime.now().millisecondsSinceEpoch,
            note.updatedAt + 1,
          ),
          synced: false,
          changeId: const Uuid().v4(),
        ),
      );
      await loadNotes();
      unawaited(syncService.sync());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível alterar a nota. Tente novamente.'),
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    final pending = await database.pendingNotes(uid);
    if (!mounted) return;
    if (pending.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Há alterações pendentes'),
          content: const Text(
            'Elas ficarão neste aparelho e serão enviadas quando você entrar nesta conta novamente. Deseja sair?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ficar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    try {
      await AuthService().logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível sair. Tente novamente.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncService.removeListener(onSyncChanged);
    syncService.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = syncService.syncing
        ? 'Sincronizando...'
        : syncService.error ??
              (syncService.pending > 0
                  ? '${syncService.pending} alteração(ões) aguardando envio'
                  : 'Notas em dia com o Firebase');
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
        onPressed: () => openNote(),
        backgroundColor: const Color(0xFF6C4AB6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova nota'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: const TextStyle(
                    color: Color(0xFF77717F),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      syncService.error != null
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                      size: 19,
                      color: const Color(0xFF6C4AB6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(status, style: const TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      tooltip: 'Sincronizar agora',
                      onPressed: syncService.syncing ? null : syncService.sync,
                      icon: const Icon(Icons.sync_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar título ou conteúdo',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar pesquisa',
                            onPressed: searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(category),
                        initialValue: category ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Todas'),
                          ),
                          ...categories.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => category = value == '' ? null : value);
                          loadNotes();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<bool>(
                      tooltip: 'Ordenar notas',
                      icon: const Icon(Icons.sort_rounded),
                      initialValue: byCreation,
                      onSelected: (value) {
                        setState(() => byCreation = value);
                        loadNotes();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: false,
                          child: Text('Última atualização'),
                        ),
                        PopupMenuItem(
                          value: true,
                          child: Text('Data de criação'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Notas'),
                      selected: !archived,
                      onSelected: (_) {
                        setState(() => archived = false);
                        loadNotes();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Arquivadas'),
                      selected: archived,
                      onSelected: (_) {
                        setState(() => archived = true);
                        loadNotes();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : localError != null
                      ? Center(
                          child: TextButton(
                            onPressed: loadNotes,
                            child: Text(localError!),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await syncService.sync();
                            await loadNotes();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 100),
                            children: notes.isEmpty
                                ? [
                                    const SizedBox(height: 50),
                                    const Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 64,
                                      color: Color(0xFF6C4AB6),
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: Text(
                                        searchController.text.isNotEmpty ||
                                                category != null
                                            ? 'Nenhuma nota encontrada.'
                                            : archived
                                            ? 'Nenhuma nota arquivada.'
                                            : 'Crie sua primeira nota.',
                                      ),
                                    ),
                                  ]
                                : notes
                                      .map(
                                        (note) => NoteCard(
                                          note: note,
                                          onTap: () => openNote(note),
                                          onDelete: () =>
                                              changeNote(note, delete: true),
                                          onArchive: () => changeNote(note),
                                        ),
                                      )
                                      .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
