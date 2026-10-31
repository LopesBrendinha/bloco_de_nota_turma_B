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

  List<Note> notes = [];

  @override
  void initState() {
    super.initState();

    startUp();
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

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final result = await repository.getNotes(user.uid);

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

            const SizedBox(height: 20),

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