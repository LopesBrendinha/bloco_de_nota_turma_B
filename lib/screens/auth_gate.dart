import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/notes_repository.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'notes_page.dart';

/// Decide a primeira tela de acordo com o usuário autenticado.
///
/// Com a sessão guardada, quem abre o aplicativo vai direto para as notas.
class AuthGate extends StatefulWidget {
  final NotesRepository repository;
  final AuthService authService;

  const AuthGate({
    super.key,
    required this.repository,
    required this.authService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? subscription;
  User? user;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    subscription = widget.authService.authStateChanges.listen(onAuthChanged);
  }

  void onAuthChanged(User? newUser) {
    if (newUser == null) {
      widget.repository.stop();
    } else {
      widget.repository.start(newUser.uid);
    }

    setState(() {
      user = newUser;
      ready = true;
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = user;
    if (currentUser == null) {
      return LoginPage(authService: widget.authService);
    }

    return NotesPage(
      key: ValueKey(currentUser.uid),
      repository: widget.repository,
      authService: widget.authService,
      email: currentUser.email ?? '',
    );
  }
}
