import 'package:blocodenotasturmab/firebase_options.dart';
import 'package:blocodenotasturmab/screens/login_page.dart';
import 'package:blocodenotasturmab/screens/notes_page.dart';
import 'package:blocodenotasturmab/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // O cache offline do Firestore fica desligado: quem guarda os dados no
  // aparelho é o SQLite. Assim existe uma única cópia local e uma falha de
  // rede aparece como erro, em vez de ficar escondida numa fila interna.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  runApp(const GrafiteApp());
}

class GrafiteApp extends StatelessWidget {
  const GrafiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grafite',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Mostra o login ou as notas conforme o estado do Firebase Auth. A sessão
/// persiste entre aberturas do app; ao sair, volta para o login sozinho.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return NotesPage(key: ValueKey(user.uid), user: user);
      },
    );
  }
}
