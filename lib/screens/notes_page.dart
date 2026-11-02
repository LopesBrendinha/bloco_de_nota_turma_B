import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
import '../services/note_sync_service.dart';
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
  final NoteSyncService syncService = NoteSyncService();

  List<Note> notes = [];
  bool loading = true;
  bool synchronizing = false;
  bool syncAgain = false;
  String? syncMessage;

  @override
  void initState() {
    super.initState();

    loadNotes();
  }

  Future<void> loadNotes() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        loading = false;
        notes = [];
      });
      return;
    }

    setState(() {
      loading = true;
    });

    bool loaded = false;

    try {
      final result = await database.getNotes(user.uid);

      if (mounted) {
        setState(() {
          notes = result;
        });
      }
      loaded = true;
    } catch (e) {
      showMessage('Não foi possível carregar as notas.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }

    if (loaded && mounted) {
      await synchronizeNotes();
    }
  }

  Future<void> synchronizeNotes() async {
    if (!mounted) return;

    if (synchronizing) {
      syncAgain = true;
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      synchronizing = true;
      syncMessage = 'Sincronizando notas...';
    });

    String message;

    try {
      await syncService.synchronize(user.uid);
      final pending = await database.getPendingNotes(user.uid);
      message = pending.isEmpty
          ? 'Notas sincronizadas.'
          : 'Há alterações locais pendentes. Toque em sincronizar.';
    } on TimeoutException {
      message = 'Sem conexão. Suas notas locais estão preservadas. Tente sincronizar novamente.';
    } on FirebaseException catch (e) {
      message = e.code == 'permission-denied'
          ? 'Sua conta não tem permissão para sincronizar as notas.'
          : 'Não foi possível acessar a nuvem. Suas notas locais estão preservadas.';
    } catch (e) {
      message = 'Não foi possível sincronizar. Suas notas locais estão preservadas.';
    }

    try {
      final result = await database.getNotes(user.uid);

      if (mounted && FirebaseAuth.instance.currentUser?.uid == user.uid) {
        setState(() {
          notes = result;
          syncMessage = message;
        });
      }
    } catch (e) {
      showMessage('Não foi possível atualizar a lista de notas.');
    } finally {
      if (mounted) {
        setState(() {
          synchronizing = false;
        });
      }
    }

    if (syncAgain && mounted) {
      syncAgain = false;
      await synchronizeNotes();
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> deleteNote(int id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await database.deleteNote(id, user.uid);
      await loadNotes();
      showMessage('Nota excluída.');
    } catch (e) {
      showMessage('Não foi possível excluir a nota.');
    }
  }

  Future<void> logout() async {
    try {
      await authService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      showMessage('Não foi possível sair da conta.');
    }
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
            tooltip: 'Sincronizar notas',
            onPressed: synchronizing ? null : synchronizeNotes,
            icon: const Icon(Icons.sync),
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

            if (syncMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                syncMessage!,
                style: const TextStyle(color: Color(0xFF77717F), fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),

            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

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

                      const Text(
                        'Nenhuma nota ainda',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Crie sua primeira nota.',
                        style: TextStyle(color: Color(0xFF77717F)),
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

                    return NoteCard(
                      note: note,

                      onTap: () => openEditNote(note),

                      onDelete: () => deleteNote(note.id!),
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
