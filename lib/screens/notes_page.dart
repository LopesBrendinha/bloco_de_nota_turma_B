import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/note_repository.dart';
import '../models/note.dart';
import '../services/auth_service.dart';
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

  bool offline = false;

  @override
  void initState() {
    super.initState();

    loadNotes();
    syncNotes();
  }

  Future<void> loadNotes() async {
    // Recuperamos o usuário atualmente
    // autenticado no Firebase.
    final user = FirebaseAuth.instance.currentUser;

    // Se não houver usuário,
    // não podemos buscar as notas.
    if (user == null) return;

    // Enviamos o UID para o banco local.
    //
    // O banco irá buscar somente as notas
    // pertencentes a esse usuário.
    final result = await repository.getNotes(user.uid);

    if (mounted) {
      // Atualizamos a lista utilizada
      // pela interface.
      setState(() {
        notes = result;
      });
    }
  }

  Future<void> syncNotes() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final online = await repository.sync(user.uid);

    await loadNotes();

    if (mounted) {
      setState(() {
        offline = !online;
      });
    }
  }

  Future<void> deleteNote(Note note) async {
    setState(() {
      notes.remove(note);
    });

    final sent = await repository.deleteNote(note);

    await loadNotes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
              ? 'Nota excluída com sucesso.'
              : 'Nota foi excluída localmente, e será removida do servidor quando houver conexão.',
          )
        )
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
    // Abre a tela responsável pelo formulário.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteFormPage()),
    );

    // Quando o usuário voltar para essa página,
    // buscamos novamente as notas.
    await loadNotes();
  }

  Future<void> openEditNote(Note note) async {
    // Passamos a nota selecionada
    // para a tela de edição.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    // Quando retornar da edição,
    // atualizamos a lista.
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
            onPressed: syncNotes,
            icon: const Icon(Icons.sync_rounded)
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

            const SizedBox(height: 20),

            if (offline)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 20),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: Color(0xFFB26A00)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Você está offline. Mostrando notas salvas no dispositivo.',
                        style: TextStyle(color: Color(0xFF8A5300)),
                      ),
                    ),
                  ]
                )
              ),

            if (notes.isEmpty)
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
                child: RefreshIndicator(
                  onRefresh: syncNotes,
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
                )
              ),
          ],
        ),
      ),
    );
  }
}
